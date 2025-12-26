# Phase 4: Notification System & Smart Alerts

## Overview
Build a comprehensive notification system that keeps users informed about important financial events, anomalies, and opportunities. Supports in-app notifications, email digests, and configurable alert triggers.

---

## 1. Core Notification Types

### Transaction Alerts
**Large Transactions:**
- Trigger: Transaction > user-defined threshold (e.g., $500)
- Content: "Large expense: $1,200 at Best Buy"
- Purpose: Fraud detection, spending awareness

**Unusual Category Spending:**
- Trigger: Category spending > 150% of average
- Content: "Your Dining spending is 2x higher than usual"
- Purpose: Budget awareness, anomaly detection

**Duplicate Transactions:**
- Trigger: Same merchant + amount within 24 hours
- Content: "Possible duplicate: $49.99 at Netflix"
- Purpose: Error detection

### Account Alerts
**Low Balance Warning:**
- Trigger: Balance < threshold OR projection shows upcoming low
- Content: "Your checking account will drop below $500 in 3 days"
- Purpose: Overdraft prevention

**Sync Failures:**
- Trigger: Account sync fails 2+ consecutive times
- Content: "Wells Fargo connection needs attention"
- Purpose: Data freshness awareness

**Unusual Account Activity:**
- Trigger: Transaction count or volume spike
- Content: "15 transactions today (usual: 3)"
- Purpose: Fraud detection, unusual activity awareness

### Budget Alerts
**Over Budget:**
- Trigger: Category spending > budgeted amount
- Content: "Groceries: $520 / $400 (130%)"
- Purpose: Budget adherence

**Approaching Budget Limit:**
- Trigger: Spending > 80% of budget with >7 days remaining
- Content: "You've used 85% of your Dining budget with 12 days left"
- Purpose: Proactive budget management

**Under Budget:**
- Trigger: Month end approaching, budget <50% utilized
- Content: "You have $200 left in your Entertainment budget"
- Purpose: Spending opportunity awareness

### Goal Alerts
**Milestone Reached:**
- Trigger: Goal progress crosses 25%, 50%, 75%, 100%
- Content: "You're halfway to your vacation goal! ($5,000 / $10,000)"
- Purpose: Motivation, progress celebration

**Off Track:**
- Trigger: Goal progress falls behind expected timeline
- Content: "Your emergency fund goal is 2 weeks behind schedule"
- Purpose: Goal awareness, adjustment prompt

**Goal Deadline Approaching:**
- Trigger: 30/14/7 days before target_date
- Content: "Your car fund goal is due in 2 weeks. $1,200 remaining."
- Purpose: Deadline awareness

### Recurring Transaction Alerts
**Missing Expected Transaction:**
- Trigger: Expected transaction didn't occur (from Phase 3)
- Content: "Expected Verizon payment ($80) didn't process"
- Purpose: Catch missed bills

**Amount Variance:**
- Trigger: Recurring transaction amount > 20% different than expected
- Content: "Electric bill is $40 higher than usual ($180 vs $140)"
- Purpose: Unexpected charge awareness

**Upcoming Bills:**
- Trigger: Bill due in 1-3 days
- Content: "Reminder: Rent ($1,800) due tomorrow"
- Purpose: Bill payment reminder

### Financial Health Alerts
**Savings Rate Change:**
- Trigger: Savings rate changes >5% month-over-month
- Content: "Your savings rate improved to 18% (was 12%)"
- Purpose: Behavioral awareness

**Net Worth Milestone:**
- Trigger: Net worth crosses round numbers ($0, $10K, $100K, etc.)
- Content: "Congratulations! Your net worth just crossed $100,000"
- Purpose: Milestone celebration

---

## 2. Database Architecture

### New Table: `notifications`
**Purpose:** Store all notifications with read/action state

**Schema:**
```ruby
create_table :notifications, id: :uuid do |t|
  t.references :family, type: :uuid, null: false, foreign_key: true
  t.references :user, type: :uuid, foreign_key: true # optional, can be family-wide
  
  # Notification content
  t.string :notification_type, null: false # "large_transaction", "low_balance", etc.
  t.string :title, null: false
  t.text :body
  t.string :icon # Lucide icon name
  t.string :severity, default: "info" # info, warning, error, success
  
  # Related objects
  t.string :related_type # polymorphic: Transaction, Account, Budget, Goal, etc.
  t.uuid :related_id
  
  # Metadata
  t.jsonb :metadata, default: {} # extra data for rendering/actions
  
  # State tracking
  t.datetime :read_at
  t.datetime :actioned_at
  t.datetime :dismissed_at
  t.datetime :expires_at # auto-dismiss old notifications
  
  # Delivery tracking
  t.boolean :sent_via_email, default: false
  t.datetime :email_sent_at
  
  t.timestamps
end

add_index :notifications, [:family_id, :created_at]
add_index :notifications, [:user_id, :read_at]
add_index :notifications, [:notification_type, :created_at]
add_index :notifications, [:related_type, :related_id]
add_index :notifications, :expires_at
```

### New Table: `notification_preferences`
**Purpose:** User/family preferences for alert triggers

**Schema:**
```ruby
create_table :notification_preferences, id: :uuid do |t|
  t.references :family, type: :uuid, null: false, foreign_key: true
  t.references :user, type: :uuid, foreign_key: true # null = family default
  
  # Alert type enablement
  t.string :notification_type, null: false # matches notifications.notification_type
  t.boolean :enabled, default: true
  t.boolean :email_enabled, default: false
  t.boolean :in_app_enabled, default: true
  
  # Thresholds and configuration
  t.jsonb :config, default: {} # type-specific settings
  # Examples:
  # { "threshold": 500 } for large_transaction
  # { "days_before": 7 } for goal_deadline
  # { "percentage": 80 } for budget_alert
  
  t.timestamps
end

add_index :notification_preferences, [:family_id, :notification_type], unique: true, name: "idx_notif_prefs_family_type"
add_index :notification_preferences, [:user_id, :notification_type], unique: true, name: "idx_notif_prefs_user_type"
```

---

## 3. Notification Service Architecture

### NotificationService
Central service for creating and delivering notifications:

**Core Responsibilities:**
- Create notifications with proper metadata
- Check user preferences before creating
- Handle duplicate detection (don't spam)
- Trigger delivery channels (in-app, email)
- Manage notification lifecycle

**Key Methods:**
```ruby
NotificationService.notify(
  family:,
  user: nil, # optional, family-wide if nil
  type:,
  title:,
  body:,
  related: nil, # ActiveRecord object
  severity: :info,
  metadata: {}
)
```

**Duplicate Prevention:**
- Check if similar notification exists (same type + related object)
- Within time window (e.g., 24 hours)
- Don't create if duplicate found
- Update existing notification instead

**Preference Checking:**
- Query `notification_preferences` for user/family
- Respect enabled/disabled flags
- Apply threshold logic from config
- Skip creation if disabled

---

## 4. Alert Detection System

### Background Jobs for Detection
Create jobs to monitor conditions and trigger alerts:

**NotificationDetectionJob:**
- Runs every 1-6 hours (depending on alert type)
- Checks all families for trigger conditions
- Creates notifications via NotificationService
- Logs detection metrics

**Alert-Specific Detection Logic:**

**LargeTransactionDetector:**
- Query transactions created in last sync
- Compare to user threshold
- Create notification if exceeded

**LowBalanceDetector:**
- Check current account balances
- Run cash flow projections (Phase 3)
- Alert if balance < threshold or projection shows low

**BudgetDetector:**
- Calculate current month spending per category
- Compare to budget allocations
- Alert at 80%, 100%, 120% thresholds

**GoalProgressDetector:**
- Check goal progress vs expected timeline
- Detect milestone crosses
- Alert if behind or milestone reached

**RecurringTransactionDetector:**
- Check expected transactions (from Phase 3)
- Compare to actual synced transactions
- Alert on missing or variance

---

## 5. UI Components

### NotificationCenter Dropdown
Header component for in-app notifications:

**Location:** Navigation bar, top-right

**Display:**
- Bell icon with unread count badge
- Click to open dropdown menu
- List of recent notifications (10-20)
- "Mark all as read" action
- "View all" link to full page

**Notification Item:**
- Icon (based on type/severity)
- Title and body text
- Timestamp (relative: "5 minutes ago")
- Related object link (click to view)
- Dismiss button

**Visual States:**
- Unread: Bold text, colored background
- Read: Normal text, transparent background
- Color coding by severity (info=blue, warning=yellow, error=red, success=green)

**Interactions:**
- Click notification → mark as read, navigate to related object
- Click dismiss → soft delete or mark dismissed
- Auto-mark as read after viewing for 2+ seconds

### NotificationsPage
Full-page view of all notifications:

**URL:** `/notifications`

**Features:**
- Tabbed view: All / Unread / By Type
- Infinite scroll or pagination
- Bulk actions: mark all read, dismiss all
- Filter by date range, type, severity
- Search notifications by content

**List View:**
- Grouped by day ("Today", "Yesterday", "Last Week")
- Same notification item design as dropdown
- Show more detail than dropdown version

---

## 6. Email Digest System

### Daily/Weekly Digest
Configurable email summary of notifications:

**Digest Types:**
1. **Daily Summary** - Sent each morning
2. **Weekly Rollup** - Sent Monday mornings
3. **Real-time** - Immediate for critical alerts only

**Content Sections:**
- Unread notification count
- Top 5 most important notifications
- Grouped by category (transactions, budgets, goals)
- Quick action links (view transaction, check budget)
- "View all" link to notification center

**User Configuration:**
- Enable/disable digest
- Choose frequency (daily/weekly/off)
- Select notification types to include
- Set delivery time preference

**Implementation:**
- Scheduled job via sidekiq-cron
- Use ActionMailer for emails
- HTML + plain text versions
- Unsubscribe link in footer

---

## 7. Real-Time Delivery

### ActionCable for Live Notifications
Push notifications to active users in real-time:

**Channel: NotificationChannel**
- Subscribe per family
- Broadcast new notifications to all connected family members
- Update notification center badge count
- Play subtle sound/animation (optional)

**Broadcasting Logic:**
```ruby
# After creating notification
ActionCable.server.broadcast(
  "notification_channel_#{family.id}",
  {
    notification: notification.as_json,
    unread_count: family.notifications.unread.count
  }
)
```

**Client-Side Handling:**
- Stimulus controller subscribes to channel
- Receives broadcasts and updates UI
- Prepends new notification to dropdown
- Updates badge count
- Shows toast/banner for high-severity

---

## 8. Smart Notification Logic

### Notification Prioritization
Prevent notification fatigue:

**Priority Levels:**
1. **Critical:** Potential fraud, sync errors, overdraft risk
2. **High:** Budget overages, goal deadlines, large transactions
3. **Medium:** Budget warnings, missing recurring, milestones
4. **Low:** Insights, tips, achievements

**Rate Limiting:**
- Max 5 notifications per day per user
- Group similar notifications (e.g., "3 large transactions today")
- Suppress low-priority if recent high-priority sent
- Daily digest can include unlimited (but summarized)

**Smart Batching:**
- Group related notifications: "3 budget categories are over limit"
- Batch updates: "2 accounts need reconnection"
- Combine duplicate types within time window

### Contextual Intelligence
Customize notifications based on user behavior:

**Learn User Patterns:**
- Track which notifications user dismisses quickly
- Track which notifications user acts on
- Adjust future thresholds/types accordingly

**Time-Based Logic:**
- Don't send low-priority notifications late at night
- Send bill reminders at user's preferred time
- Batch non-urgent into digest

**Behavior Triggers:**
- If user hasn't logged in for 7 days, send recap email
- If user actively budgeting, increase budget alert frequency
- If user ignoring goals, reduce goal notifications

---

## 9. Notification Preferences UI

### Settings Page: Notification Preferences
Allow granular control over notifications:

**Page Structure:**

**Section 1: General Settings**
- Email digest frequency (off, daily, weekly)
- Preferred delivery time
- Enable/disable sounds and animations
- In-app notification persistence (how long before auto-dismiss)

**Section 2: Alert Types**
- List all notification types in groups:
  - 📊 Transactions
  - 💰 Accounts
  - 📈 Budgets
  - 🎯 Goals
  - 🔄 Recurring Transactions
  - 📉 Financial Health

**Per Alert Type Controls:**
- Toggle: In-app enabled/disabled
- Toggle: Email enabled/disabled
- Threshold input (where applicable)
- Example notification preview

**Section 3: Test & Preview**
- "Send test notification" buttons
- Preview email digest format
- Recent notification history

---

## 10. Controller & Routes

### NotificationsController
Handle notification UI and actions:

**Actions:**
- `index` - List all notifications
- `show` - View single notification (mark as read)
- `mark_as_read` - Mark one or multiple as read
- `dismiss` - Dismiss notification
- `dismiss_all` - Clear all notifications
- `preferences` - Notification settings page
- `update_preferences` - Save notification settings

**API Endpoints (for frontend):**
- `GET /notifications.json` - JSON list for dropdown
- `POST /notifications/:id/read` - Mark as read
- `GET /notifications/unread_count` - Badge count

### Routes
```ruby
resources :notifications, only: [:index, :show] do
  member do
    post :mark_as_read
    post :dismiss
  end
  collection do
    post :mark_all_read
    post :dismiss_all
    get :unread_count
  end
end

resource :notification_preferences, only: [:show, :update]
```

---

## 11. Integration with Existing Features

### Transaction Creation/Sync
Hook notification checks into sync process:

**After Transaction Import:**
1. Check for large transactions
2. Check for unusual category spending
3. Check for potential duplicates
4. Check budget impact
5. Check goal contribution match

**Implementation:**
- Add to `Transaction.after_create` callback
- Or in `SyncJob.perform` after batch import
- Use `NotificationDetectionJob` for async processing

### Account Balance Updates
Trigger alerts on balance changes:

**After Balance Sync:**
1. Check if balance crossed low threshold
2. Run quick cash flow projection
3. Alert if overdraft risk detected

### Budget Period Rollover
Check budget status at period boundaries:

**End of Month:**
1. Summarize budget performance
2. Notify on categories exceeded
3. Create digest of month's activity

### Goal Progress Updates
Alert when goal state changes:

**After Goal Update:**
1. Check milestone crosses
2. Check on-track status
3. Alert if significant change

---

## 12. Testing Strategy

### Unit Tests
- Test notification creation with various parameters
- Test preference checking logic
- Test duplicate detection
- Test severity assignment
- Test expiration logic

### Integration Tests
- Test end-to-end notification flow (trigger → create → deliver)
- Test email digest generation and delivery
- Test real-time ActionCable broadcasting
- Test notification center UI interactions

### Detection Tests
- Test each detector type with edge cases
- Mock date/time for scheduled detection
- Test threshold logic accuracy
- Test batching and grouping

---

## 13. Performance Considerations

### Query Optimization
- Index on `family_id + created_at` for recent notifications
- Index on `user_id + read_at` for unread queries
- Use `counter_cache` for unread count if needed

### Background Processing
- Run detection jobs during off-peak hours
- Stagger family processing to avoid spikes
- Use batching for bulk notification creation

### Caching
- Cache unread count per user (1-5 minute TTL)
- Cache notification list for dropdown (30 second TTL)
- Invalidate on new notification or read action

---

## 14. Implementation Order

1. **Database:** Create notifications and notification_preferences tables
2. **Models:** Build Notification and NotificationPreference models
3. **Service:** Implement NotificationService with preference checking
4. **Detection Jobs:** Build detector classes and background jobs
5. **Controller:** Create NotificationsController with index/actions
6. **UI Components:** Build notification center dropdown
7. **Full Page:** Create notifications index page
8. **Preferences UI:** Build notification settings page
9. **Email Digest:** Implement mailer and scheduled job
10. **ActionCable:** Add real-time broadcasting
11. **Integrations:** Hook detectors into sync/transaction flows
12. **Smart Logic:** Add prioritization and batching
13. **Testing:** Comprehensive test coverage

---

## Success Criteria

- [ ] Notifications created for all defined trigger types
- [ ] User preferences respected (enabled/disabled, thresholds)
- [ ] Duplicate notifications prevented
- [ ] In-app notification center displays unread count
- [ ] Dropdown shows recent notifications
- [ ] Full notifications page with filtering/search
- [ ] Email digests send on schedule
- [ ] Real-time notifications via ActionCable
- [ ] Mark as read/dismiss functionality works
- [ ] Notification preferences UI allows full customization
- [ ] Performance remains fast with 1000+ notifications
- [ ] All tests pass with edge case coverage
- [ ] Mobile-responsive notification UI
- [ ] Notification center accessible via keyboard navigation

---

## Future Enhancements (Post-Phase 4)

- Push notifications via web push API
- Mobile app notifications (iOS/Android)
- SMS notifications for critical alerts
- Slack/Discord webhook integrations
- Custom notification rules (user-defined triggers)
- Notification analytics (open rate, action rate)
- Smart notification timing based on user activity patterns
- Voice notifications via smart home devices
- Notification templates for advanced customization
