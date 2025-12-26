# Phase 3: Cash Flow Forecasting & Projections

## Overview
Build a forward-looking cash flow projection system that uses recurring transactions, scheduled bills, and account balances to predict future financial state. Helps users anticipate shortfalls and plan ahead.

---

## 1. Core Functionality

### Cash Flow Calendar
**Purpose:** Visual timeline of expected income and expenses

**Key Features:**
- Daily/weekly/monthly views of projected transactions
- Color-coded by type: income (green), expenses (red), transfers (gray)
- Balance projection line showing expected account balance over time
- Click date to see transaction details
- Differentiate confirmed vs projected transactions

**Data Sources:**
- Existing `RecurringTransaction` model for recurring patterns
- Pending transactions from synced accounts
- Scheduled budget allocations
- Upcoming loan/debt payments

### Balance Projection
**Purpose:** Predict future account balances based on scheduled activity

**Calculation Logic:**
1. Start with current account balance
2. Add/subtract pending transactions (already synced but not cleared)
3. Apply recurring transaction projections
4. Factor in scheduled bill payments
5. Include goal contributions if automated

**Time Horizons:**
- Next 7 days (short-term)
- Next 30 days (medium-term)
- Next 90 days (long-term)

**Accuracy Considerations:**
- Higher confidence for near-term (7 days)
- Lower confidence for far-term (90 days)
- Display confidence level/range

---

## 2. Data Architecture

### Projection Engine Strategy
**Don't store projections** - calculate on-demand:

**Why Not Store:**
- Projections change constantly as actuals come in
- Would require complex invalidation logic
- Real-time is more accurate than stale projections

**Caching Strategy:**
- Cache projection calculations for 1-4 hours
- Invalidate cache when:
  - New transactions sync
  - Recurring patterns updated
  - Account balances change
  - User edits scheduled transactions

### Extended RecurringTransaction Usage
Leverage existing `RecurringTransaction` model:

**Current Capabilities:**
- Already has `expected_day_of_month`
- Already has `amount_min`, `amount_avg`, `amount_max`
- Already generates projected entries

**Enhancements Needed:**
- Add `confidence_score` field (0.0-1.0) based on pattern consistency
- Add `last_matched_at` to track prediction accuracy
- Consider `paused_until` for temporary skips (like paused subscriptions)

**Pattern Improvement:**
- Track variance over time to improve predictions
- Learn from misses (expected transaction didn't occur)
- Adjust amounts based on trend (e.g., utilities increasing)

---

## 3. Projection Service

### CashFlow::ProjectionService
Service object for generating projections:

**Initialization:**
- Takes `family`, `start_date`, `end_date`, optional `account_ids`
- Loads relevant recurring transactions
- Fetches pending transactions

**Core Method: `generate_projection`**
Returns structured data:
```
{
  projections: [
    {
      date: Date,
      type: :income | :expense | :transfer,
      amount: Money,
      description: String,
      confidence: Float (0.0-1.0),
      source: :recurring | :pending | :scheduled,
      source_id: UUID (recurring_transaction_id or transaction_id)
    }
  ],
  balance_curve: [
    { date: Date, balance: Money, confidence: Float }
  ]
}
```

**Algorithm Steps:**
1. **Fetch Base Data:**
   - Current account balances
   - Pending transactions (from sync providers)
   - Active recurring transactions within date range

2. **Generate Daily Projections:**
   - For each day in range:
     - Add recurring transactions scheduled for that day
     - Include pending transactions
     - Calculate running balance
   
3. **Calculate Confidence:**
   - Pending transactions: 0.95 (very likely)
   - Auto recurring (matched >3x): 0.85 (high confidence)
   - Manual recurring: 0.70 (medium confidence)
   - New recurring (<3 matches): 0.50 (low confidence)

4. **Handle Uncertainty:**
   - For recurring with variance, use pessimistic estimate (max for expenses, min for income)
   - Apply decay to confidence further in future
   - Flag dates where balance drops below zero

---

## 4. UI Components

### CashFlowCalendar Component
Interactive calendar view:

**Visual Design:**
- Grid layout (week or month view)
- Each day shows:
  - Net cash flow (income - expenses)
  - Color indicator (green surplus, red deficit)
  - Account balance at end of day
  - Icon count for transaction types
  
**Interactions:**
- Click day to expand transaction list
- Hover to preview transactions
- Toggle between views (daily/weekly/monthly)
- Filter by account or transaction type

**Implementation Approach:**
- Stimulus controller for interactivity
- Server-rendered with Turbo Frames for day details
- Use existing date helpers for formatting

### BalanceProjectionChart
Line chart showing balance over time:

**Chart Elements:**
- Solid line: actual historical balance
- Dashed line: projected balance
- Shaded area: confidence range (min/max scenarios)
- Markers: significant events (bills, paychecks)
- Zero line: highlight when balance approaches zero

**Alert Indicators:**
- Red zone when projected balance < $0
- Yellow zone when < user-defined threshold
- Green zone when healthy

**Use Existing Charts:**
- Leverage `app/javascript/controllers/time_series_chart_controller.js`
- Extend with projection-specific styling

---

## 5. Smart Features

### Low Balance Alerts
Detect and warn about potential overdrafts:

**Detection Logic:**
- Run projections for next 30 days
- Identify days where balance drops below threshold
- Group consecutive low-balance days
- Calculate earliest alert date

**User Configuration:**
- Set threshold per account (e.g., "warn if < $500")
- Set alert timing (e.g., "7 days before")
- Enable/disable per account

**Alert Display:**
- Show in dashboard widget
- Badge on accounts page
- Optional email notification (Phase 4)

### Cash Flow Insights
AI-generated observations:

**Insight Examples:**
- "Your balance will drop below $500 on Jan 15 due to rent payment"
- "You have 3 bills totaling $450 due next week"
- "Your account balance is trending lower each month"
- "Consider moving $200 to savings before expenses hit"

**Generation Strategy:**
- Template-based for common patterns
- Variables filled from projection data
- Prioritize by severity and timing
- Limit to top 3-5 most actionable insights

### What-If Scenarios
Allow users to test scenarios:

**Scenario Types:**
1. **Add Income:** "What if I get a $5K bonus?"
2. **Add Expense:** "What if I make this $2K purchase?"
3. **Change Recurring:** "What if I cancel this subscription?"
4. **Adjust Timing:** "What if I pay this bill early/late?"

**Implementation:**
- Form to input scenario parameters
- Recalculate projection with adjustments
- Show side-by-side comparison (current vs scenario)
- Don't persist - temporary calculation only

---

## 6. Integration Points

### Dashboard Widget: "Upcoming Cash Flow"
Add collapsible section to dashboard:

**Display:**
- Next 7 days of significant transactions
- Projected balance at end of period
- Warning if balance goes low
- Link to full calendar view

**Data Shown:**
- Date, description, amount for each item
- Running balance after each transaction
- Confidence indicator (dot or percentage)

### Account Detail Page
Add projection section to individual accounts:

**Display:**
- Mini balance chart (next 30 days)
- List of upcoming transactions for this account
- Expected balance at month end

**Actions:**
- "View full projection" → opens dedicated page
- "Set low balance alert" → configure threshold

### Budget Integration
Connect projections to budget tracking:

**Budget vs Projection:**
- Compare budgeted spending to projected spending
- Warn if projections exceed budget categories
- Show how recurring expenses align with budget

**Display:**
- In budget detail page, show "Projected spending" vs "Budgeted"
- Highlight categories at risk of overspend
- Suggest budget adjustments based on patterns

---

## 7. Controller Structure

### CashFlowController
New controller for projection views:

**Actions:**
- `index` - Calendar view of projections
- `balance_chart` - JSON endpoint for chart data
- `day_details` - Turbo Frame for clicked day
- `scenario` - Calculate what-if scenario

**Query Parameters:**
- `start_date`, `end_date` - Date range
- `account_ids[]` - Filter to specific accounts
- `view` - Calendar view mode (day/week/month)

**Response Formats:**
- HTML for main views
- JSON for chart data
- Turbo Stream for interactive updates

---

## 8. Recurring Transaction Intelligence

### Pattern Learning
Improve recurring transaction predictions:

**Track Accuracy:**
- After each sync, match actual transactions to projections
- Store hit rate per recurring pattern
- Adjust confidence scores based on accuracy

**Amount Refinement:**
- For variable amounts (utilities), track trend
- Use weighted average favoring recent months
- Detect seasonal patterns (heating bills in winter)

**Timing Refinement:**
- Learn if transactions come early/late vs expected
- Adjust expected_day_of_month based on actuals
- Handle irregular patterns (every 4 weeks vs monthly)

### Missing Transaction Detection
Alert when expected transaction doesn't occur:

**Detection:**
- If recurring transaction expected on day X
- And sync completes after day X
- And no matching transaction found
- → Flag as "missing"

**User Action:**
- Show notification: "Expected Netflix charge didn't occur"
- Options: "Mark as paid", "Skip this month", "Update pattern"

---

## 9. Performance Optimization

### Calculation Efficiency
Projections can be computationally expensive:

**Optimization Strategies:**
1. **Limit Range:** Default to 90 days max
2. **Lazy Load:** Only calculate visible date range
3. **Cache Heavily:** Cache per family/account/date range combo
4. **Parallel Processing:** Calculate multiple accounts in parallel
5. **Incremental Updates:** Only recalculate changed portions

**Caching Keys:**
```
cache_key = "projection/#{family.id}/#{account_ids.sort.join('-')}/#{start_date}/#{end_date}/#{cache_version}"
cache_version = [
  family.updated_at,
  family.recurring_transactions.maximum(:updated_at),
  family.transactions.maximum(:updated_at)
].max
```

### Progressive Loading
For long date ranges:

**Strategy:**
1. Load first 30 days immediately (fast)
2. Stream remaining days as they calculate (progressive)
3. Use Turbo Streams to append data
4. Show loading indicators for pending ranges

---

## 10. Testing Strategy

### Projection Accuracy Tests
- Test with known recurring patterns
- Verify balance calculations with sample data
- Test edge cases: month end, leap years, weekends
- Test confidence score calculations

### Performance Tests
- Benchmark projection generation time
- Test with large datasets (100+ recurring transactions)
- Verify cache invalidation works correctly
- Test concurrent projection requests

### Integration Tests
- Test calendar renders correctly
- Test day detail expansion
- Test scenario calculation
- Test alerts trigger correctly

---

## 11. Routes

```ruby
# config/routes.rb
namespace :cash_flow do
  get '/', to: 'cash_flow#index', as: :index
  get 'balance_chart', to: 'cash_flow#balance_chart'
  get 'day/:date', to: 'cash_flow#day_details', as: :day
  post 'scenario', to: 'cash_flow#scenario'
end

# Or simpler:
resource :cash_flow, only: [:show] do
  get 'day/:date', action: :day, as: :day, on: :collection
  post 'scenario', on: :collection
end
```

---

## 12. AI Assistant Integration

### Query Support
Add AI functions for cash flow questions:

**Function: `get_cash_flow_projection`**
- Input: time period (next week, next month, etc.)
- Output: Summary of projected cash flow
- Use: "What's my cash flow looking like next week?"

**Function: `check_balance_health`**
- Input: optional account_id
- Output: Alert if balance will go low
- Use: "Will I have enough money to cover my bills?"

**Function: `explain_projection`**
- Input: date or transaction
- Output: Explain why transaction is projected
- Use: "Why do you think I'll spend $100 on Jan 15?"

---

## 13. User Configuration

### Settings Page: Cash Flow Preferences
Allow users to customize:

**Projection Settings:**
- Default projection range (30/60/90 days)
- Confidence threshold (hide low-confidence items)
- Balance alert threshold per account

**Calendar Settings:**
- Default calendar view (week/month)
- Week start day (Sunday/Monday)
- Transaction grouping preferences

**Notification Settings:**
- Low balance alert timing (7/14 days before)
- Daily/weekly digest of upcoming transactions
- Specific recurring transaction alerts

---

## 14. Implementation Order

1. **Enhance RecurringTransaction:** Add confidence score, last_matched_at
2. **Build ProjectionService:** Core calculation logic with tests
3. **Create Controller:** CashFlowController with index action
4. **Build Calendar View:** Basic calendar layout with projections
5. **Add Balance Chart:** Integrate with existing chart infrastructure
6. **Dashboard Widget:** Add upcoming transactions widget
7. **Day Details:** Implement expandable day view with Turbo Frame
8. **Low Balance Alerts:** Detection and display logic
9. **Account Integration:** Add projections to account detail page
10. **What-If Scenarios:** Scenario calculator
11. **Pattern Learning:** Implement accuracy tracking
12. **AI Functions:** Add cash flow query support

---

## Success Criteria

- [ ] Projects cash flow for next 90 days accurately
- [ ] Uses recurring transactions as primary data source
- [ ] Includes pending transactions from synced accounts
- [ ] Calculates balance projection per account
- [ ] Displays confidence scores for projections
- [ ] Shows calendar view with daily/weekly/monthly modes
- [ ] Renders balance projection chart with uncertainty range
- [ ] Detects and alerts on potential low balance situations
- [ ] Provides actionable insights based on projections
- [ ] Supports what-if scenario calculations
- [ ] Integrates with dashboard and account pages
- [ ] Performs well with large transaction histories
- [ ] All tests pass with edge case coverage
- [ ] Caching works correctly and invalidates appropriately

---

## Future Enhancements (Post-Phase 3)

- Machine learning for pattern detection
- Seasonal adjustment (holiday spending, summer utilities)
- Bill negotiation suggestions (based on historical patterns)
- Optimal payment timing recommendations
- Integration with goals (project goal completion dates)
- Multi-account cash flow optimization
- Automated savings recommendations based on surplus projections
- Category-level projections (not just transaction-level)
