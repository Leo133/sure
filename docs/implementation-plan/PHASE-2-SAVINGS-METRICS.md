# Phase 2: Savings Rate & Financial Health Metrics

## Overview
Add calculated financial health metrics that analyze spending patterns, savings behavior, and financial stability. These metrics provide actionable insights into overall financial wellness.

---

## 1. Core Metrics to Calculate

### Savings Rate
**Definition:** Percentage of income saved each period  
**Formula:** `(Income - Expenses) / Income × 100`

**Calculation Logic:**
- Source data from existing `family.income_statement` methods
- Filter transactions by income vs expense categories
- Calculate for multiple time periods: monthly, quarterly, yearly
- Store historical snapshots for trend analysis

**Edge Cases:**
- Negative income months (use 0% or mark as N/A)
- Zero income months (skip or interpolate)
- Transfer/refund transactions (already filtered by Entryable)

### Debt-to-Income Ratio
**Definition:** Monthly debt payments as percentage of gross income  
**Formula:** `Total Monthly Debt Payments / Gross Monthly Income × 100`

**Calculation Logic:**
- Sum all loan account minimum payments
- Add credit card minimum payments (calculate from balance + APR)
- Get average monthly income from last 3-6 months
- Thresholds: <36% healthy, 36-43% manageable, >43% high risk

**Data Sources:**
- `Account.loan` accountables for loan payments
- `Account.credit_card` for credit card balances
- Transaction categories: loan_payment, cc_payment kinds

### Emergency Fund Coverage
**Definition:** Months of expenses covered by liquid savings  
**Formula:** `Liquid Account Balances / Average Monthly Expenses`

**Calculation Logic:**
- Sum checking + savings account balances (liquid assets only)
- Calculate median monthly expenses from last 6-12 months
- Recommendations: 3-6 months for employed, 6-12 for self-employed
- Color coding: red <3, yellow 3-6, green >6

**Account Selection:**
- Include: depository accounts (checking, savings)
- Exclude: investment, retirement, property, vehicles

### Net Worth Trend
**Definition:** Change in net worth over time  
**Formula:** `(Current Net Worth - Previous Period Net Worth) / Previous Period Net Worth × 100`

**Calculation Logic:**
- Leverage existing `family.balance_sheet.net_worth` method
- Store monthly snapshots in new `financial_snapshots` table
- Calculate MoM (month-over-month) and YoY (year-over-year) changes
- Track velocity: accelerating vs decelerating growth

---

## 2. Data Storage Strategy

### New Table: `financial_snapshots`
**Purpose:** Store point-in-time financial metrics for historical analysis

**Key Fields:**
- `family_id`, `snapshot_date` (date, indexed)
- `net_worth`, `liquid_assets`, `total_debt` (Money fields)
- `monthly_income`, `monthly_expenses`, `monthly_savings` (Money fields)
- `savings_rate`, `debt_to_income_ratio`, `emergency_fund_months` (decimals)
- `metadata` (JSONB for additional calculated values)

**Indexing:**
- Compound index on `(family_id, snapshot_date)` for time-series queries
- Unique constraint on `(family_id, snapshot_date)` to prevent duplicates

**Population Strategy:**
- Background job runs monthly (1st of month) to capture snapshots
- Can backfill historical data using transaction history
- Store raw values to allow recalculation as formulas evolve

---

## 3. Model Architecture

### FinancialSnapshot Model
Follow the pattern of `Budget` and `RecurringTransaction`:

**Key Responsibilities:**
- Store point-in-time financial state
- Calculate derived metrics on-demand
- Provide comparison methods (vs previous month/year)
- Generate trend data for charts

**Core Methods:**
- `calculate_for_family!(family, date)` - Generate snapshot
- `metrics_summary` - Return hash of all metrics with labels
- `trend_data(metric, period)` - Time series for charting
- `comparison_to_previous` - MoM/YoY deltas

**Concerns to Include:**
- `Monetizable` for currency fields
- Consider `Chartable` if building visualizations

### Family Model Extension
Add methods to Family model for real-time metric calculation:

```
# Real-time calculations (not stored)
def current_savings_rate(period: :month)
def current_debt_to_income_ratio
def emergency_fund_coverage
def net_worth_change(period: :month)
```

These methods calculate on-the-fly using current data, while FinancialSnapshot stores historical values.

---

## 4. Calculation Services

### FinancialMetrics::Calculator
Create service object pattern (place in `app/models/concerns/` or keep in Family model):

**Responsibilities:**
- Encapsulate metric calculation logic
- Handle edge cases and null states
- Provide consistent rounding and formatting
- Return structured data with metadata

**Methods to Implement:**
- `calculate_savings_rate(start_date, end_date)`
- `calculate_debt_to_income(reference_date)`
- `calculate_emergency_fund(reference_date)`
- `calculate_net_worth_velocity(periods)`

**Why Separate:**
- Complex calculations don't bloat Family model
- Easier to test in isolation
- Can be called from multiple contexts (dashboard, reports, snapshots)

---

## 5. Background Job Strategy

### FinancialSnapshotJob
Run on monthly schedule via sidekiq-cron:

**Schedule:** `0 2 1 * *` (2 AM on 1st of month)

**Job Logic:**
1. Iterate all active families
2. Check if snapshot exists for previous month
3. If missing, calculate and create snapshot
4. Log success/failures for monitoring

**Error Handling:**
- Skip families with insufficient data (<30 days of transactions)
- Retry on transient failures (DB locks, etc.)
- Alert on persistent failures

### Backfill Strategy
Create one-time rake task for historical snapshots:

```
rake financial_snapshots:backfill[family_id, months]
```

This allows populating historical data when feature launches.

---

## 6. UI Integration

### Dashboard Widget: "Financial Health Score"
Add new collapsible dashboard section:

**Display:**
- Overall health score (weighted average of metrics)
- 4 key metrics with icons and color coding
- Sparklines showing 6-month trends
- "View Details" link to full report page

**Color Coding:**
- Green: Healthy range
- Yellow: Needs attention
- Red: Critical/high risk

**User Controls:**
- Toggle period (monthly, quarterly, yearly)
- Expand/collapse individual metrics
- Click metric for detailed breakdown

### New Page: Financial Health Report
Create dedicated page at `/financial_health`:

**Sections:**
1. **Summary Cards** - Current values of all 4 metrics
2. **Trend Charts** - Line charts for each metric over time
3. **Insights Panel** - AI-generated observations and recommendations
4. **Historical Table** - Monthly snapshots in tabular format

**Actions:**
- Export data as CSV
- Compare to previous period
- Set alert thresholds (Phase 4)

---

## 7. Insights & Recommendations Engine

### Logic for Insights
Based on metric values, provide contextual guidance:

**Savings Rate Insights:**
- <10%: "Your savings rate is low. Consider budgeting strategies."
- 10-20%: "Good savings habit! Try increasing by 1-2% each quarter."
- >20%: "Excellent savings rate! You're building wealth effectively."

**DTI Insights:**
- >43%: "High debt burden. Prioritize debt reduction strategies."
- 36-43%: "Manageable debt. Consider paying extra on high-interest debts."
- <36%: "Healthy debt levels. You have good borrowing capacity."

**Emergency Fund Insights:**
- <3 months: "Build emergency fund to 3-6 months of expenses."
- 3-6 months: "Solid emergency fund. Consider investing excess."
- >6 months: "Strong safety net. Optimize cash vs investments."

**Implementation:**
- Store insight templates in YAML file (`config/financial_insights.yml`)
- Select appropriate insight based on metric ranges
- Personalize with family name and specific values

---

## 8. Controller Structure

### FinancialHealthController
Create new controller for health metrics:

**Actions:**
- `index` - Dashboard with current metrics and trends
- `export` - CSV download of historical snapshots
- `recalculate` - Manual trigger to refresh metrics (admin)

**Authorization:**
- Scope to `Current.family`
- Ensure only family members can view
- Consider role-based access for sensitive metrics

---

## 9. ViewComponent Strategy

### UI::MetricCard
Reusable component for displaying individual metrics:

**Props:**
- `label`, `value`, `trend` (up/down/flat)
- `color` (green/yellow/red based on health)
- `icon` (Lucide icon name)
- `sparkline_data` (array of values for mini chart)

**Variants:**
- Compact (dashboard widget)
- Expanded (full report page)
- Comparison (side-by-side periods)

### UI::FinancialHealthScore
Overall health visualization:

**Display:**
- Circular progress indicator (0-100 score)
- Breakdown by metric contribution
- Tooltips explaining score calculation

**Calculation:**
- Weight metrics: 30% savings rate, 30% DTI, 25% emergency fund, 15% net worth trend
- Normalize each to 0-100 scale
- Combine with weights for overall score

---

## 10. Chart Integration

### Trend Visualizations
Use existing D3.js chart infrastructure:

**Chart Types Needed:**
- Line chart for metric trends over time
- Area chart for income/expense/savings stacked view
- Gauge chart for health score (semicircle)
- Sparklines for dashboard cards

**Data Format:**
Return from controller in format expected by existing chart helpers:
```
{
  series: [{ name: "Savings Rate", data: [[date, value], ...] }],
  currency: "USD",
  format: "percentage"
}
```

---

## 11. Metric Benchmarking

### Optional: Aggregate Benchmarks
Show how user compares to anonymized aggregate:

**Privacy Considerations:**
- Fully anonymized, aggregated only
- Opt-in feature with clear disclosure
- No PII transmitted or stored

**Display:**
- "Your savings rate: 15% (Average: 12%)"
- Percentile ranking: "Top 30% of users"
- Age/income bracket comparisons (if available)

**Implementation:**
- Separate encrypted aggregation table
- Update weekly via background job
- Cache aggregate stats for performance

---

## 12. Testing Strategy

### Model Tests
Test calculation accuracy:
- Savings rate with various income/expense scenarios
- DTI with different account types
- Emergency fund with mixed account types
- Edge cases: zero income, negative expenses, no debt

### Job Tests
- Snapshot creation on schedule
- Idempotency (don't duplicate snapshots)
- Backfill logic for historical data
- Error handling for incomplete data

### Integration Tests
- Dashboard widget displays correctly
- Metrics update after transaction changes
- Export functionality works
- Insights generate appropriate recommendations

---

## 13. Performance Considerations

### Caching Strategy
Metrics can be expensive to calculate:

**Cache Layers:**
1. **Page-level:** Cache full financial health page for 1 hour
2. **Fragment-level:** Cache individual metric cards for 30 minutes
3. **Data-level:** Cache snapshot queries via Rails.cache

**Cache Invalidation:**
- Clear family metrics cache after sync completes
- Clear after manual transaction edits
- Clear after account balance updates

**Implementation:**
- Use `Rails.cache.fetch` with family-scoped keys
- Touch family updated_at to bust cache
- Consider Russian doll caching for dashboard

### Query Optimization
- Preload associations when fetching snapshots
- Use database views for complex aggregations
- Index snapshot_date for time-series queries
- Consider materialized views for large families

---

## 14. Localization

Add to `config/locales/en.yml`:
- Metric names and descriptions
- Insight templates with variables
- Health score labels (Poor, Fair, Good, Excellent)
- Recommendation text

Support multiple languages:
- Use I18n.t for all user-facing text
- Format numbers/percentages per locale
- Date formatting respects locale

---

## 15. Routes

```ruby
# config/routes.rb
namespace :financial_health do
  get '/', to: 'financial_health#index', as: :index
  get 'export', to: 'financial_health#export'
  post 'recalculate', to: 'financial_health#recalculate'
end

# Or simpler:
resource :financial_health, only: [:show] do
  get :export
  post :recalculate
end
```

---

## Implementation Order

1. **Database:** Create `financial_snapshots` migration
2. **Model:** Build FinancialSnapshot with calculation logic
3. **Tests:** Write comprehensive metric calculation tests
4. **Family Methods:** Add real-time metric methods to Family
5. **Background Job:** Implement FinancialSnapshotJob with cron schedule
6. **Controller:** Create FinancialHealthController
7. **Components:** Build UI::MetricCard and related components
8. **Views:** Create financial health report page
9. **Dashboard:** Add financial health widget to dashboard
10. **Charts:** Integrate trend visualizations
11. **Insights:** Add recommendation engine
12. **Backfill:** Create rake task for historical data

---

## Success Criteria

- [ ] Savings rate calculates accurately for all time periods
- [ ] Debt-to-income ratio accounts for all debt types
- [ ] Emergency fund coverage uses only liquid accounts
- [ ] Net worth trend shows MoM and YoY changes
- [ ] Monthly snapshots generate automatically
- [ ] Dashboard widget displays current metrics
- [ ] Full report page shows historical trends
- [ ] Charts render correctly for 6-12 month periods
- [ ] Insights provide contextual recommendations
- [ ] Performance remains fast with 2+ years of data
- [ ] All tests pass with edge case coverage
- [ ] Works correctly with multi-currency families

---

## Future Enhancements (Post-Phase 2)

- Custom metric formulas (user-defined KPIs)
- Goal integration (track metrics toward goal milestones)
- Alerts when metrics cross thresholds (Phase 4)
- PDF report generation for sharing with advisors
- Compare households (anonymized benchmarking)
- Budget efficiency score (actual vs budgeted variance)
- Investment performance metrics (Phase 5)
