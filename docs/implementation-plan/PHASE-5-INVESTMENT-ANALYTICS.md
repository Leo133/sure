# Phase 5: Advanced Investment Analytics

## Overview
Enhance investment account tracking with portfolio analytics, performance metrics, dividend tracking, and asset allocation insights. Build on existing investment infrastructure to provide professional-grade analytics.

---

## 1. Core Investment Metrics

### Time-Weighted Return (TWR)
**Purpose:** Measure portfolio performance independent of cash flows

**Why TWR:**
- Eliminates impact of deposits/withdrawals
- Industry standard for comparing to benchmarks
- Fair measure of investment decisions

**Calculation Approach:**
1. Divide time period into sub-periods at each cash flow
2. Calculate return for each sub-period
3. Chain sub-period returns together
4. Formula: `TWR = [(1 + R₁) × (1 + R₂) × ... × (1 + Rₙ)] - 1`

**Data Requirements:**
- Daily account values (from existing valuations)
- Cash flow dates and amounts (deposits/withdrawals)
- Existing `Holding` and `Security` models have most data

**Implementation Location:**
- Add to `Investment::Account` model as instance method
- Service object: `Investment::PerformanceCalculator`
- Cache results daily, recalculate monthly

### Internal Rate of Return (IRR)
**Purpose:** Measure actual return including cash flow timing

**Why IRR:**
- Shows true dollar-weighted return
- Accounts for timing of contributions
- Useful for personal return calculation

**Calculation Approach:**
- Use Newton-Raphson method or XIRR formula
- Inputs: All cash flows (dates + amounts) + current value
- Solve for rate where NPV = 0

**When to Show:**
- Use TWR for "Portfolio Performance" (apples-to-apples)
- Use IRR for "Your Personal Return" (actual money growth)
- Display both side-by-side with explanation

### Annualized Return
**Purpose:** Normalize returns to yearly percentage

**Calculation:**
```
For period < 1 year: (1 + return)^(365/days) - 1
For period ≥ 1 year: (1 + return)^(1/years) - 1
```

**Display:**
- Show for YTD, 1Y, 3Y, 5Y, Since Inception
- Color code vs benchmarks (S&P 500, etc.)

---

## 2. Portfolio Analysis

### Asset Allocation
**Current State:** Some data exists in holdings

**Enhancements Needed:**
- Aggregate holdings by asset class (stocks, bonds, cash, real estate, crypto)
- Show target vs actual allocation
- Rebalancing recommendations
- Historical allocation drift tracking

**Classification Strategy:**

**Option 1: Security-Level Metadata**
- Add `asset_class` to `Security` model
- Use `security_type` (existing field) as base
- Map types: stock→equity, mutual_fund→check fund type, etc.

**Option 2: Holdings-Level Override**
- Add `asset_class_override` to `Holding` (for user customization)
- Falls back to security's classification
- Allows manual adjustments

**Asset Classes:**
- US Stocks (Large/Mid/Small Cap)
- International Stocks (Developed/Emerging)
- Bonds (Government/Corporate/Municipal)
- Real Estate (REITs)
- Commodities
- Cash & Cash Equivalents
- Crypto
- Other/Alternative

**Allocation Views:**
1. **Current Allocation** - Pie/donut chart with percentages
2. **Target Allocation** - User-defined goals
3. **Drift Analysis** - Difference between current and target
4. **Rebalancing Needed** - Buy/sell amounts to reach target

### Sector & Geography Diversification
**Purpose:** Analyze concentration risk

**Sector Breakdown:**
- Technology, Healthcare, Finance, Energy, etc.
- Aggregate from holdings → securities
- Fetch sector data from price providers (existing integrations)
- Store in `securities.metadata` JSONB field

**Geographic Breakdown:**
- US vs International
- Region breakdown (North America, Europe, Asia, etc.)
- Country-level detail where available

**Concentration Alerts:**
- Warn if single security > 20% of portfolio
- Warn if single sector > 30% of portfolio
- Suggest diversification strategies

### Holdings Performance
**Individual Holding Metrics:**
- Total return ($ and %)
- Unrealized gain/loss
- Cost basis (already tracked)
- Current value (already tracked)
- Days held
- Dividend yield (if applicable)

**Portfolio-Level Aggregates:**
- Total unrealized gain/loss
- Total realized gain/loss (from trades)
- Best/worst performers
- Largest holdings by value

---

## 3. Dividend & Income Tracking

### Dividend Collection
**Current State:** Basic transaction import exists

**Enhancements:**
- Classify transactions as dividends (use `kind` field or category)
- Link dividends to specific securities/holdings
- Track qualified vs ordinary dividends
- Track foreign tax withheld

**Data Model:**
- Add `dividend_type` to transactions: qualified, ordinary, return_of_capital
- Add `withheld_tax` field for foreign dividends
- Link transaction to holding via `holdable` polymorphic (if not already)

### Income Analytics
**Metrics to Calculate:**
1. **Total Dividend Income** - Sum by period (month/quarter/year)
2. **Dividend Yield** - Annual dividends / portfolio value
3. **Dividend Growth Rate** - YoY change in dividend income
4. **Income by Security** - Which holdings generate most income
5. **Income Calendar** - Projected future dividend payments

**Dividend Yield Calculation:**
```
Portfolio Dividend Yield = (Total Annual Dividends / Portfolio Value) × 100
Per-Holding Yield = (Annual Dividends / Holding Value) × 100
```

**Projected Income:**
- Use historical dividend frequency per security
- Estimate next payment dates
- Project annual income based on current holdings

### Income Dashboard
**Display Elements:**
- Income chart (bar chart by month)
- Current yield vs historical
- Top income-generating holdings
- Upcoming dividend calendar
- Income diversification (by security)

---

## 4. Cost Basis & Tax Reporting

### Cost Basis Tracking
**Current State:** Holdings have `amount` and `currency`

**Enhancements Needed:**
- Track purchase date per lot (FIFO/LIFO)
- Multiple lots per holding (buy at different times)
- Average cost basis calculation
- Cost basis adjustment for splits, dividends

**Lot Tracking Table:**
```ruby
# Optional: holding_lots table for detailed tracking
create_table :holding_lots do |t|
  t.references :holding, type: :uuid
  t.decimal :quantity, precision: 19, scale: 4
  t.decimal :cost_basis, precision: 19, scale: 4
  t.string :currency
  t.date :acquisition_date
  t.string :lot_method # fifo, lifo, specific_id
  t.timestamps
end
```

**Simpler Approach:**
- Store lot history in `Holding.metadata` JSONB
- Calculate weighted average cost basis
- Track total cost basis (sum of all purchases - sales)

### Tax-Loss Harvesting
**Identify Opportunities:**
- Find holdings with unrealized losses
- Check wash sale rules (30-day window)
- Suggest similar securities to swap into
- Estimate tax benefit

**Display:**
- List of positions with losses > $1,000
- Days until wash sale period expires
- Potential tax savings
- "Execute Harvest" action (track intent)

### Realized Gains Report
**Generate Annual Report:**
- All trades in tax year
- Calculate gain/loss per trade
- Classify as short-term (<1 year) or long-term
- Total capital gains/losses
- Export to CSV for tax filing

---

## 5. Benchmark Comparison

### Add Benchmark Tracking
**Purpose:** Compare portfolio performance to indexes

**Benchmarks to Support:**
- S&P 500 (US Large Cap)
- Total Stock Market (VTI)
- International Stocks (VXUS)
- Bond Aggregates (AGG)
- 60/40 Portfolio (60% stocks, 40% bonds)
- Custom user-defined benchmarks

**Data Source Options:**
1. **Existing Price Providers:** Fetch benchmark data like security prices
2. **Static Historical Data:** Store common benchmark returns in CSV
3. **External API:** Use financial data APIs (Alpha Vantage, Yahoo Finance)

**Store Benchmark Data:**
```ruby
# New table: benchmark_values
create_table :benchmark_values do |t|
  t.string :benchmark_ticker, null: false # SPY, VTI, etc.
  t.date :value_date, null: false
  t.decimal :price, precision: 19, scale: 4
  t.timestamps
end

add_index :benchmark_values, [:benchmark_ticker, :value_date], unique: true
```

**Comparison Display:**
- Line chart: Portfolio vs benchmark over time
- Table: Returns by period (1M, 3M, YTD, 1Y, 3Y, 5Y)
- Outperformance/underperformance in $ and %
- Risk metrics: volatility, Sharpe ratio (advanced)

---

## 6. Performance Attribution

### Analyze Return Sources
**What Contributed to Performance:**

**Attribution Categories:**
1. **Asset Allocation** - Return from allocation decisions
2. **Security Selection** - Return from picking winners
3. **Market Timing** - Return from entry/exit timing
4. **Fees & Expenses** - Drag from costs
5. **Cash Drag** - Impact of uninvested cash

**Calculation Approach:**
- Compare actual portfolio returns to benchmark
- Decompose variance into attribution factors
- Complex calculation - consider simplified version

**Simpler Version:**
- Show which holdings contributed most to return
- Calculate contribution: `(Holding Return) × (Holding Weight)`
- Rank holdings by contribution

---

## 7. Risk Metrics

### Volatility (Standard Deviation)
**Purpose:** Measure portfolio risk

**Calculation:**
- Calculate daily returns over period
- Standard deviation of returns
- Annualize: `Daily StdDev × √252`

**Display:**
- Compare to benchmark volatility
- Risk-adjusted return (Sharpe ratio)

### Maximum Drawdown
**Purpose:** Largest peak-to-trough decline

**Calculation:**
- Track running maximum portfolio value
- Calculate decline from peak
- Identify largest drawdown period

**Use Case:**
- Show worst historical decline
- Compare to benchmark drawdown
- Recovery time analysis

### Beta & Correlation
**Purpose:** How portfolio moves with market

**Calculation:**
- Requires benchmark data
- Beta = Covariance(Portfolio, Benchmark) / Variance(Benchmark)
- Correlation = Correlation coefficient

**Interpretation:**
- Beta > 1: More volatile than market
- Beta < 1: Less volatile than market
- High correlation: Moves with market

---

## 8. Investment Dashboard

### New Page: Investment Analytics
**URL:** `/investments/analytics` or `/portfolio`

**Sections:**

**1. Performance Summary Card:**
- Total portfolio value
- YTD return ($ and %)
- All-time return
- Unrealized gain/loss

**2. Returns Chart:**
- Time series of portfolio value
- Overlaid benchmark comparison
- Toggle time periods
- Zoom/pan interactions

**3. Asset Allocation:**
- Donut chart showing breakdown
- Target vs actual bars
- Rebalancing suggestions

**4. Top Holdings Table:**
- Name, ticker, value, allocation %, return
- Sort by various columns
- Click for security detail

**5. Dividend Income:**
- Annual income total
- Yield percentage
- Income chart (monthly bars)
- Upcoming dividends list

**6. Performance Metrics Grid:**
- TWR, IRR, annualized returns
- By time period: 1M, 3M, YTD, 1Y, 3Y, 5Y, All
- Comparison to benchmarks

**7. Risk Metrics:**
- Volatility, max drawdown
- Sharpe ratio, beta
- Risk-adjusted return

---

## 9. Service Architecture

### Investment::PerformanceCalculator
**Responsibilities:**
- Calculate TWR, IRR for given period
- Handle cash flow adjustments
- Cache results for performance

**Usage:**
```ruby
calculator = Investment::PerformanceCalculator.new(account)
calculator.time_weighted_return(start_date, end_date)
calculator.internal_rate_of_return(start_date, end_date)
calculator.annualized_return(period: :ytd)
```

### Investment::AllocationAnalyzer
**Responsibilities:**
- Classify holdings by asset class
- Calculate current allocation
- Compare to target allocation
- Generate rebalancing recommendations

**Methods:**
- `current_allocation` - Hash of asset_class → value
- `allocation_drift` - Current vs target differences
- `rebalancing_trades` - Suggested buy/sell to rebalance

### Investment::DividendTracker
**Responsibilities:**
- Aggregate dividend transactions
- Calculate yields
- Project future dividends
- Generate income calendar

**Methods:**
- `total_income(period)` - Sum of dividends
- `current_yield` - Annual yield percentage
- `projected_annual_income` - Estimate based on history
- `upcoming_dividends(days: 90)` - Expected payments

---

## 10. Data Updates & Jobs

### Daily: Investment Snapshot Job
**Purpose:** Capture daily portfolio values for performance calculations

**Tasks:**
1. For each investment account:
   - Calculate total value (sum of holdings)
   - Store in valuations table (already exists)
   - Calculate daily return
   - Update rolling metrics (30-day, 90-day returns)

**Scheduling:** Run nightly after market close (e.g., 10 PM ET)

### Weekly: Benchmark Update Job
**Purpose:** Fetch latest benchmark prices

**Tasks:**
1. List all tracked benchmarks
2. Fetch latest prices from provider
3. Store in `benchmark_values`
4. Calculate benchmark returns

### Monthly: Portfolio Analytics Job
**Purpose:** Calculate complex metrics that don't need daily updates

**Tasks:**
1. Recalculate TWR/IRR for standard periods
2. Update allocation history
3. Generate tax reports
4. Check rebalancing opportunities

---

## 11. UI Components

### UI::PortfolioSummaryCard
**Display:**
- Total value (large, prominent)
- Unrealized gain/loss with color
- Period return with arrow
- Mini sparkline of recent values

### UI::AllocationChart
**Visualization:**
- Donut chart with hover tooltips
- Legend with percentages
- Click slice to drill into holdings

### UI::PerformanceChart
**Features:**
- Line chart with multiple series
- Time period selector (1M, 3M, YTD, etc.)
- Benchmark overlay toggle
- Tooltips on hover
- Export chart as image

### UI::HoldingRow
**Table Row Component:**
- Security name + ticker
- Quantity held
- Current price
- Total value
- Unrealized gain/loss ($ and %)
- Return percentage with color
- Actions: View detail, Sell

---

## 12. Integration with Existing Features

### Account Detail Page
Add investment analytics section:
- Performance summary for this account
- Holdings table with returns
- Cash flow history (contributions/withdrawals)
- Link to full analytics page

### Dashboard Widget
**"Portfolio Performance":**
- Show total investment value
- YTD return
- Mini chart
- Link to full analytics

### Transaction Categorization
**Improve Investment Transaction Handling:**
- Auto-categorize dividends, interest, capital gains
- Link to holdings/securities automatically
- Detect stock splits, mergers, spin-offs

---

## 13. Testing Strategy

### Performance Calculation Tests
- Test TWR with known cash flows
- Test IRR calculation accuracy
- Test edge cases: zero returns, negative returns
- Verify annualization formulas

### Allocation Tests
- Test classification logic
- Test rebalancing calculations
- Test target vs actual comparisons

### Data Accuracy Tests
- Verify holding value calculations
- Test cost basis tracking
- Test gain/loss calculations

---

## 14. Performance & Optimization

### Caching Strategy
**Cache Expensive Calculations:**
- Cache TWR/IRR for standard periods (1 day)
- Cache allocation breakdown (1 hour)
- Cache benchmark comparisons (1 day)
- Invalidate on new transactions or holdings

**Database Optimization:**
- Index holding valuations by date
- Preload securities and holdings
- Use database views for complex aggregations

### Background Processing
- Calculate metrics asynchronously
- Store results in cache or database table
- Update UI via Turbo Streams when ready

---

## 15. Implementation Order

1. **Enhance Models:** Add asset_class to Security, improve Holding
2. **Valuation History:** Ensure daily account values are captured
3. **Performance Service:** Build PerformanceCalculator with TWR/IRR
4. **Allocation Service:** Build AllocationAnalyzer
5. **Dividend Service:** Build DividendTracker
6. **Benchmark Data:** Create benchmark_values table and fetch job
7. **Controller:** Create Investment::AnalyticsController
8. **Basic Page:** Build portfolio analytics page with performance chart
9. **Components:** Create UI components for charts and displays
10. **Asset Allocation:** Add allocation section with charts
11. **Dividend Dashboard:** Add income tracking section
12. **Benchmark Comparison:** Add comparison charts and tables
13. **Cost Basis:** Implement lot tracking or simplified approach
14. **Tax Reports:** Build realized gains export
15. **Dashboard Integration:** Add investment widgets
16. **Testing:** Comprehensive test coverage

---

## Success Criteria

- [ ] Calculates TWR and IRR accurately for any time period
- [ ] Shows annualized returns for 1M, 3M, YTD, 1Y, 3Y, 5Y, All
- [ ] Displays asset allocation with target vs actual
- [ ] Provides rebalancing recommendations
- [ ] Tracks dividend income and calculates yields
- [ ] Shows upcoming dividend calendar
- [ ] Compares portfolio performance to benchmarks
- [ ] Displays top holdings with individual returns
- [ ] Calculates cost basis and unrealized gains
- [ ] Generates realized gains report for tax year
- [ ] Shows risk metrics (volatility, drawdown)
- [ ] Performance chart renders correctly with benchmark overlay
- [ ] All calculations handle edge cases (zero cash, splits, etc.)
- [ ] Fast performance with large portfolios (100+ holdings)
- [ ] All tests pass with comprehensive coverage

---

## Future Enhancements (Post-Phase 5)

- Options & derivatives tracking
- Private equity & alternative investment handling
- Multi-currency portfolio return calculations
- Factor exposure analysis (size, value, momentum)
- Risk-adjusted performance metrics (Sortino, Calmar)
- Monte Carlo retirement projections
- Tax-aware rebalancing strategies
- Automated rebalancing execution
- Integration with brokerage APIs for trade execution
- ESG (Environmental, Social, Governance) scoring
- Crypto-specific metrics (staking yields, gas fees)
- Real estate investment analytics (cap rate, cash-on-cash)
