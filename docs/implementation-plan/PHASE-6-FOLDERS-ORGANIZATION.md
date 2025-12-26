# Phase 6: Account Organization & Custom Views

## Overview
Implement flexible account organization with folders/groups, custom sorting, favorite accounts, and personalized views. Helps users manage many accounts efficiently and focus on what matters most.

---

## 1. Core Organization Features

### Account Folders
**Purpose:** Group related accounts for easier navigation

**Use Cases:**
- Group by institution: "Chase Accounts", "Vanguard"
- Group by purpose: "Emergency Fund", "Retirement", "Kids"
- Group by person: "John's Accounts", "Jane's Accounts"
- Group by goal: "House Down Payment", "Vacation Fund"

**Key Behaviors:**
- Hierarchical: folders can contain folders (2-3 levels deep)
- Multi-assignment: account can be in multiple folders (tagging model)
- Collapsible: expand/collapse folders in UI
- Show aggregate balance for folder
- Drag-and-drop to reorganize

### Account Tags
**Alternative to Folders:** More flexible categorization

**Difference from Folders:**
- Tags are non-hierarchical
- Accounts can have unlimited tags
- Tags are color-coded
- Filter accounts by tag(s)
- Reuse existing `Tag` model or create `AccountTag`

**Tag Examples:**
- "Active", "Closed", "Monitored"
- "High-Interest", "Tax-Advantaged"
- "Shared", "Personal"
- "Auto-Sync", "Manual"

### Favorite Accounts
**Purpose:** Quick access to most-used accounts

**Features:**
- Star/unstar accounts
- Favorites appear at top of lists
- Favorites section in dashboard
- Persist per user (not family-wide)
- Limit to 5-10 favorites

---

## 2. Database Schema

### New Table: `account_folders`
**Purpose:** Store folder structure

```ruby
create_table :account_folders, id: :uuid do |t|
  t.references :family, type: :uuid, null: false, foreign_key: true
  t.string :name, null: false
  t.text :description
  t.string :color # hex color
  t.string :lucide_icon, default: "folder"
  
  # Hierarchy
  t.references :parent_folder, type: :uuid, foreign_key: { to_table: :account_folders }
  t.integer :position, default: 0 # for manual ordering
  
  # UI state
  t.boolean :collapsed, default: false # per-user state better in separate table
  
  t.timestamps
end

add_index :account_folders, [:family_id, :position]
add_index :account_folders, :parent_folder_id
```

### Join Table: `account_folder_memberships`
**Purpose:** Many-to-many relationship

```ruby
create_table :account_folder_memberships, id: :uuid do |t|
  t.references :account, type: :uuid, null: false, foreign_key: true
  t.references :account_folder, type: :uuid, null: false, foreign_key: true
  t.integer :position, default: 0 # ordering within folder
  t.timestamps
end

add_index :account_folder_memberships, [:account_folder_id, :position]
add_index :account_folder_memberships, [:account_id, :account_folder_id], unique: true, name: "idx_account_folder_unique"
```

### Extend Existing: `accounts` table
**Add Columns:**
```ruby
add_column :accounts, :is_favorite, :boolean, default: false
add_column :accounts, :position, :integer, default: 0 # global ordering
add_column :accounts, :hidden, :boolean, default: false # hide from main view
add_column :accounts, :display_preference, :string, default: "default" # custom view modes
```

### User Preferences Table Extension
**Store Per-User Settings:**
```ruby
# Add to existing user_preferences or dashboard_preferences
{
  "accounts": {
    "favorite_ids": ["uuid1", "uuid2"],
    "collapsed_folder_ids": ["uuid3"],
    "default_view": "grid", # grid, list, compact
    "sort_by": "balance", # balance, name, updated_at, type
    "sort_direction": "desc",
    "show_hidden": false,
    "group_by": "folder" # folder, type, institution, none
  }
}
```

---

## 3. Model Architecture

### AccountFolder Model
**Responsibilities:**
- Manage folder hierarchy
- Calculate aggregate balances
- Handle folder membership
- Validate depth limits (prevent deep nesting)

**Key Methods:**
```ruby
class AccountFolder < ApplicationRecord
  belongs_to :family
  belongs_to :parent_folder, class_name: "AccountFolder", optional: true
  has_many :child_folders, class_name: "AccountFolder", foreign_key: :parent_folder_id
  has_many :account_folder_memberships, dependent: :destroy
  has_many :accounts, through: :account_folder_memberships
  
  validates :name, presence: true
  validate :depth_limit
  
  scope :roots, -> { where(parent_folder_id: nil) }
  scope :by_position, -> { order(:position) }
  
  def depth_limit
    errors.add(:parent_folder, "too deep") if depth > 3
  end
  
  def depth
    parent_folder ? parent_folder.depth + 1 : 0
  end
  
  def total_balance
    accounts.sum(:balance) + child_folders.sum(&:total_balance)
  end
  
  def all_accounts
    accounts + child_folders.flat_map(&:all_accounts)
  end
end
```

### Account Model Extensions
**Add Methods:**
```ruby
class Account
  has_many :account_folder_memberships, dependent: :destroy
  has_many :folders, through: :account_folder_memberships, source: :account_folder
  
  scope :favorites, -> { where(is_favorite: true) }
  scope :visible, -> { where(hidden: false) }
  scope :by_position, -> { order(:position) }
  
  def toggle_favorite!
    update!(is_favorite: !is_favorite)
  end
  
  def add_to_folder(folder)
    folders << folder unless folders.include?(folder)
  end
  
  def remove_from_folder(folder)
    folders.delete(folder)
  end
  
  def primary_folder
    folders.order(:created_at).first
  end
end
```

---

## 4. Organization UI

### Accounts Page Redesign
**Enhanced Layout:**

**Header Section:**
- View mode toggles: Grid, List, Compact
- Sort dropdown: Balance, Name, Type, Updated
- Filter dropdown: By folder, type, status
- Search bar: Filter accounts by name
- "New Account" and "New Folder" buttons

**Sidebar (Optional):**
- Folder tree navigation
- Click folder to filter main view
- Expand/collapse folders
- Drag accounts to folders
- Edit/delete folder actions

**Main Content:**
- Accounts displayed based on view mode
- Group by folder, type, or institution
- Show folder headers with aggregate balances
- Drag-and-drop to reorder or move folders
- Empty states for new users

**View Modes:**

1. **Grid View:**
   - Cards in responsive grid
   - 2-4 columns depending on screen
   - Show icon, name, balance, change
   - Quick actions on hover

2. **List View:**
   - Table-like rows
   - More data columns: balance, change, updated, sync status
   - Sortable columns
   - Bulk actions (select multiple)

3. **Compact View:**
   - Dense list for users with many accounts
   - Single line per account
   - Icon + name + balance only

---

## 5. Drag & Drop Interactions

### Organize Accounts via Drag
**Functionality:**
- Drag account card to folder
- Drag account within folder to reorder
- Drag folder to reorder or nest
- Visual feedback during drag (dropzones, hover states)

**Implementation:**
- Use Stimulus controller with HTML5 drag/drop API
- Or use Sortable.js library for smoother UX
- POST to `/accounts/:id/move` or `/folders/:id/move`
- Update `position` fields on reorder
- Turbo Frame reload to reflect changes

**Controller Actions:**
```ruby
class AccountsController
  def move
    @account = Account.find(params[:id])
    @account.update(position: params[:position])
    @folder = AccountFolder.find(params[:folder_id]) if params[:folder_id]
    @account.add_to_folder(@folder) if @folder
    # Respond with Turbo Stream to update UI
  end
end
```

---

## 6. Custom Views & Filters

### Saved Views
**Purpose:** Persist custom filter/sort configurations

**Examples:**
- "Emergency Funds" - Show only savings accounts in Emergency folder
- "Investment Portfolio" - All investment accounts, sorted by balance
- "Needs Attention" - Accounts with sync errors or low balances
- "Monitoring" - Closed or inactive accounts

**Data Model:**
```ruby
create_table :account_views, id: :uuid do |t|
  t.references :user, type: :uuid, null: false, foreign_key: true
  t.string :name, null: false
  t.jsonb :filters, default: {} # { folder_ids: [], types: [], favorites_only: false }
  t.jsonb :sort_config, default: {} # { sort_by: "balance", direction: "desc" }
  t.string :view_mode, default: "grid" # grid, list, compact
  t.boolean :is_default, default: false
  t.integer :position, default: 0
  t.timestamps
end
```

**UI:**
- View selector dropdown in header
- "Save current view" action
- Edit/delete saved views
- Set default view on login

### Smart Filters
**Pre-built Filters:**
- "Active Accounts" - exclude hidden/closed
- "Needs Sync" - sync failed or stale
- "Low Balance" - balance < threshold
- "High Value" - balance > threshold
- "Recently Updated" - synced in last 24 hours

**Filter UI:**
- Multi-select dropdowns
- Quick filter chips/buttons
- Clear all filters action
- Filter count indicator

---

## 7. Dashboard Integration

### Organized Account Widgets
**Folder-Based Dashboard Sections:**
- Show folder as collapsible section
- Display accounts in folder
- Aggregate folder balance
- Quick add account to folder

**Favorite Accounts Widget:**
- Dedicated section for favorites
- Quick access to common accounts
- Mini balance chart per account
- Fast navigation to account detail

**Account Health Summary:**
- Count by status (active, needs attention, syncing)
- Total balance by folder
- Sync health indicators

---

## 8. Bulk Operations

### Multi-Select Actions
**Enable Bulk Operations:**
- Select multiple accounts via checkbox
- Actions: Add to folder, Remove from folder, Hide, Delete
- Confirmation modal for destructive actions
- Progress indication for batch operations

**Use Cases:**
- Organize new accounts quickly
- Archive old accounts in bulk
- Apply tags to multiple accounts
- Export selection to CSV

**Implementation:**
- Checkbox column in list view
- "Select All" option
- Action bar appears when items selected
- POST to bulk action endpoint with account IDs

---

## 9. Account Visibility & Archiving

### Hide Accounts
**Purpose:** Declutter main view without deleting

**Behavior:**
- Hidden accounts don't appear in default views
- Still included in totals (configurable)
- Show/hide toggle in settings
- Dedicated "Hidden Accounts" view

**Use Cases:**
- Closed accounts
- Inactive credit cards
- Old 401(k) accounts
- Accounts for monitoring only

### Archive Workflow
**Graceful Account Closure:**
1. Mark account as "closed"
2. Stop auto-syncing
3. Optionally hide from main view
4. Keep transaction history
5. Show in "Archived" folder

**UI Flow:**
- "Close Account" button on account page
- Confirm modal with archival options
- Final balance snapshot
- Move to archive folder automatically

---

## 10. Controller Structure

### AccountFoldersController
**Actions:**
- `index` - List folders (for sidebar or dedicated page)
- `show` - View folder with accounts
- `new` / `create` - Create folder
- `edit` / `update` - Rename folder, change color/icon
- `destroy` - Delete folder (keep accounts)
- `move` - Reorder or nest folder

### AccountsController Extensions
**New Actions:**
- `move` - Move account to folder or reorder
- `toggle_favorite` - Star/unstar account
- `toggle_hidden` - Show/hide account
- `bulk_update` - Apply action to multiple accounts

### AccountViewsController
**Actions:**
- `index` - List saved views
- `create` - Save current filter/sort config
- `update` - Modify saved view
- `destroy` - Delete saved view
- `set_default` - Make view the default

---

## 11. ViewComponents

### UI::AccountFolderCard
**Display:**
- Folder icon and color
- Folder name
- Account count
- Total balance
- Expand/collapse button
- Edit/delete actions

### UI::AccountGridCard
**Enhanced Account Card:**
- Folder indicator (if in folder)
- Favorite star (toggle)
- Drag handle
- Quick actions menu

### UI::FolderTree
**Sidebar Component:**
- Hierarchical folder structure
- Indent nested folders
- Show account counts
- Collapsible branches
- Active folder highlighting

---

## 12. Performance Considerations

### Query Optimization
**Avoid N+1:**
- Eager load folders with accounts
- Preload folder memberships
- Use counter caches for account counts
- Cache folder balance calculations

**Indexes:**
- Compound indexes on position fields
- Foreign key indexes on joins
- Full-text search on account names

### Caching Strategy
- Cache folder tree structure (invalidate on folder changes)
- Cache folder balances (invalidate on account sync)
- Fragment cache account cards
- Use Russian doll caching for nested folders

---

## 13. Mobile Considerations

### Responsive Organization
**Mobile UI Adaptations:**
- Hamburger menu for folder navigation
- Swipe actions: favorite, hide, move to folder
- Bottom sheet for folder selection
- Simplified view modes (grid only)
- Pull-to-refresh for sync

**Touch Interactions:**
- Tap-and-hold to enter selection mode
- Swipe cards to reveal actions
- Drag-and-drop with touch events

---

## 14. Search & Discovery

### Enhanced Search
**Search Capabilities:**
- Search account names
- Search by institution
- Search by account number (masked)
- Search folder names
- Search tags

**Search UI:**
- Persistent search bar
- As-you-type filtering
- Recent searches
- Search suggestions

**Implementation:**
- Use PostgreSQL full-text search
- Or simple ILIKE queries for start
- Highlight matching text
- Show search results count

---

## 15. Import/Export Organization

### Export Folder Structure
**Purpose:** Backup or share organization

**Format:** JSON or YAML
```json
{
  "folders": [
    {
      "name": "Retirement",
      "accounts": ["account_uuid_1", "account_uuid_2"],
      "subfolders": [...]
    }
  ]
}
```

### Import Organization Template
**Purpose:** Apply common organization patterns

**Templates:**
- "Dave Ramsey Style" - Emergency fund, debt snowball, etc.
- "FIRE Movement" - Taxable, tax-deferred, tax-free buckets
- "By Institution" - Folder per bank/broker
- "By Family Member" - Folder per person

---

## 16. Routes

```ruby
resources :account_folders do
  member do
    post :move
  end
  resources :accounts, only: [], controller: 'account_folder_accounts' do
    post :add, on: :collection
    delete :remove
  end
end

resources :accounts do
  member do
    post :move
    post :toggle_favorite
    post :toggle_hidden
  end
  collection do
    post :bulk_update
  end
end

resources :account_views, only: [:index, :create, :update, :destroy] do
  member do
    post :set_default
  end
end
```

---

## 17. Testing Strategy

### Model Tests
- Test folder hierarchy depth limits
- Test folder balance aggregation
- Test account-folder associations
- Test favorite toggle
- Test bulk operations

### Controller Tests
- Test CRUD for folders
- Test moving accounts between folders
- Test reordering
- Test saved view CRUD

### Integration Tests
- Test drag-and-drop flow
- Test folder creation and assignment
- Test view saving and loading
- Test bulk selection and actions

---

## 18. Implementation Order

1. **Database:** Create account_folders and join table migrations
2. **Models:** Build AccountFolder model with associations
3. **Basic CRUD:** Controller and views for folder management
4. **Account Assignment:** Add/remove accounts from folders
5. **Folder Display:** Show folders on accounts page
6. **Reordering:** Implement position tracking and updates
7. **Drag & Drop:** Add interactive reorganization
8. **Favorites:** Implement favorite toggle and display
9. **View Modes:** Build grid, list, compact views
10. **Saved Views:** Implement custom view persistence
11. **Bulk Actions:** Multi-select and bulk operations
12. **Dashboard:** Integrate folders into dashboard
13. **Search:** Enhanced search with folder filtering
14. **Mobile:** Responsive touch interactions
15. **Testing:** Comprehensive test coverage

---

## Success Criteria

- [ ] Users can create nested folder structures (2-3 levels)
- [ ] Accounts can be assigned to multiple folders
- [ ] Folders show aggregate balances
- [ ] Drag-and-drop works for reorganization
- [ ] Favorite accounts star/unstar easily
- [ ] Hidden accounts don't appear in default view
- [ ] Grid, list, and compact view modes work
- [ ] Saved views persist filter/sort configurations
- [ ] Bulk operations work on selected accounts
- [ ] Folder tree displays hierarchically in sidebar
- [ ] Search filters by account name and folder
- [ ] Mobile UI adapts responsively
- [ ] Performance remains fast with 50+ accounts and folders
- [ ] All tests pass with comprehensive coverage

---

## Future Enhancements (Post-Phase 6)

- Shared folders across family members with permissions
- Folder-level budgets (allocate budget to folder)
- Folder-level goals (aggregate progress)
- Templates for common folder structures
- AI-suggested organization based on account names/types
- Folder color themes and customization
- Account grouping by spending patterns
- Automatic folder assignment rules
- Folder-based insights and analytics
- Export/import folder configurations
- Folder activity feeds (recent transactions)
- Hierarchical permission system for folders
