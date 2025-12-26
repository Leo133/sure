# Phase 1: Financial Goals System

## Overview
Build a goal tracking system that allows users to set savings targets, debt payoff plans, and track progress. Goals should integrate with existing accounts and transactions.

---

## 1. Database Design

### Tables to Create

**`goals` table:**
- Core fields: `family_id`, `name`, `goal_type`, `target_amount`, `currency`, `target_date`, `status`
- Progress tracking: `current_amount`, `start_date`, `completed_at`
- Customization: `color`, `lucide_icon`, `description`
- Special: `linked_account_ids` (JSONB array) - for automatic progress tracking from specific accounts
- Milestones: JSONB field storing percentage checkpoints with reached dates

**`goal_contributions` table (optional but recommended):**
- Links: `goal_id`, optional `transaction_id`
- Fields: `amount`, `currency`, `contribution_date`, `contribution_type`, `notes`
- Purpose: Manual contribution tracking and transaction linkage

**Indexes:**
- `family_id + status` for listing active goals
- `target_date` for sorting by deadline
- `goal_id + contribution_date` for contribution history

---

## 2. Model Architecture

### Goal Model Pattern
Follow the existing pattern used by `Budget`, `RecurringTransaction`, and `Category`:

**Key Concerns to Include:**
- `Monetizable` - for handling `target_amount` and `current_amount` as Money objects
- Standard Rails validations and enums for `goal_type` and `status`

**Goal Types:**
- `savings` - Track savings toward a target
- `debt_payoff` - Track debt reduction (inverted progress)
- `net_worth` - Track net worth milestone
- `emergency_fund` - Track emergency fund (calculated from monthly expenses)
- `custom` - User-defined goals

**Core Methods to Implement:**
- `progress_percentage` - Calculate (current / target * 100)
- `on_track?` - Compare actual vs expected progress based on time elapsed
- `days_remaining` - Calculate days until target_date
- `required_monthly_contribution` - Calculate amount needed per month to reach goal
- `update_progress!` - Recalculate current_amount based on goal_type
- `check_milestones!` - Mark milestone percentages as reached
- `check_completion!` - Auto-complete when target reached

**Progress Calculation Strategy (by type):**
- Savings: Sum balances of linked accounts
- Debt Payoff: Calculate reduction from original balance
- Net Worth: Use `family.balance_sheet.net_worth`
- Emergency Fund: Calculate months of expenses covered
- Custom: Sum manual contributions

---

## 3. Controller Structure

### GoalsController
Model after `BudgetsController` and `TagsController` patterns:

**Actions:**
- `index` - List active and completed goals (follow Budget pattern with tabs)
- `show` - Goal details with progress chart and contribution history
- `new/create` - Form with goal type selector and linked account picker
- `edit/update` - Allow target/date adjustments, trigger `update_progress!`
- `destroy` - Soft delete or full delete with confirmation
- `add_contribution` (member route) - Quick-add manual contribution

**View Strategy:**
- Use Turbo Frames for inline editing (like budgets)
- Show progress bar with color coding (green=on track, yellow=behind, red=far behind)
- Display milestone markers on progress bar
- List recent contributions with dates

---

## 4. Integration Points

### Dashboard Widget
Add to `pages_controller.rb` dashboard sections:
- Show 3 active goals sorted by priority (target_date first, then created_at)
- Display compact progress bars with goal name and percentage
- Link to full goals page
- Follow existing dashboard section pattern with collapsible option

### Family Model
Add association and helper methods:
```
has_many :goals, dependent: :destroy
```

### Account Model
Consider adding:
- `linked_goals` helper to show which goals track this account
- Display in account detail view

---

## 5. ViewComponent Strategy

### UI::GoalCard
Create reusable card component following existing `DS` component patterns:
- Props: `goal` object
- Show: name, icon, progress bar, current/target amounts, days remaining
- Status badge: completed, on_track, behind
- Color coding based on progress

### UI::GoalProgressBar
Reusable progress visualization:
- Props: `percentage`, `color`, `show_milestones`
- Render milestone markers at 25%, 50%, 75%
- Smooth animation on load

---

## 6. Testing Strategy

### Model Tests
Follow existing test patterns in `test/models/`:
- Test progress calculations for each goal_type
- Test `on_track?` logic with various scenarios
- Test milestone marking
- Test auto-completion when target reached
- Test contribution tracking

### Controller Tests
- Test CRUD operations
- Test `add_contribution` action
- Test progress updates trigger correctly

### Integration Tests
- Test goal creation flow
- Test linking accounts to goals
- Test manual contribution flow

---

## 7. Background Job Considerations

### Optional: GoalProgressUpdateJob
Run nightly to update all active goals:
- Iterate through `Goal.active`
- Call `update_progress!` on each
- Send notifications for newly reached milestones
- Mark goals as complete if target reached

This follows the pattern used by `SyncJob` and `RecurringTransactionJob`.

---

## 8. User Experience Flow

**Creating a Goal:**
1. Click "New Goal" button
2. Select goal type (shows different forms)
3. Enter name, target amount, optional target date
4. For savings/debt: Select linked accounts (multi-select)
5. Add optional milestones (25%, 50%, 75%, custom)
6. Save - redirects to goal show page

**Tracking Progress:**
1. Automatic: Linked accounts update goal when balances sync
2. Manual: "Add Contribution" button for one-off additions
3. Visual feedback: Progress bar fills, milestones light up
4. Notifications: When milestones reached or goal completed (Phase 2)

---

## 9. Routes

Add to `config/routes.rb`:
```ruby
resources :goals do
  member do
    post :add_contribution
  end
end
```

---

## 10. Localization

Add to `config/locales/en.yml`:
- Goal type names and descriptions
- Status labels (active, completed, paused)
- Success/error messages
- Dashboard widget text

---

## Implementation Order

1. **Database**: Create migrations for goals and goal_contributions tables
2. **Models**: Build Goal and GoalContribution with core logic
3. **Tests**: Write comprehensive model tests
4. **Controller**: Implement GoalsController with CRUD
5. **Views**: Create index, show, and form views
6. **Components**: Build UI::GoalCard and progress components
7. **Dashboard**: Add goals widget to dashboard
8. **Polish**: Add icons, colors, and animations

---

## Success Criteria

- [ ] Users can create goals with target amounts and dates
- [ ] Progress automatically updates from linked accounts
- [ ] Manual contributions can be added
- [ ] Progress bar shows visual feedback
- [ ] Milestones are tracked and marked
- [ ] Goals auto-complete when target reached
- [ ] Dashboard shows active goal summaries
- [ ] All tests pass
- [ ] Works with existing multi-currency system
