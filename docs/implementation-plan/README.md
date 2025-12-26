# Implementation Plan Overview

This directory contains detailed implementation plans for enhancing Sure with advanced financial features.

## Implementation Status

### ✅ Phase 1: Financial Goals System (COMPLETED)
**Status:** Merged to main on December 26, 2025

**What Was Implemented:**
- Database tables: `goals` and `goal_contributions`
- Goal model with progress tracking for 5 goal types:
  - Savings goals (track linked account balances)
  - Debt payoff goals (track debt reduction)
  - Net worth goals (track net worth milestones)
  - Emergency fund goals (calculate months of coverage)
  - Custom goals (manual contribution tracking)
- Full CRUD controller with add_contribution action
- Complete views: index, show, new, edit, form partial
- Comprehensive test coverage (14 tests, all passing)
- Localization support
- Family association integration

**Key Features:**
- Automatic progress updates from linked accounts
- Manual contribution tracking
- Milestone tracking (25%, 50%, 75%, 100%)
- On-track vs behind schedule detection
- Required monthly contribution calculations
- Auto-completion when target reached

**Files Changed:** 18 files, 1,228 insertions
- Models: `Goal`, `GoalContribution`
- Controller: `GoalsController`
- Views: Complete UI for goal management
- Tests: Full model test coverage

**Technical Highlights:**
- Uses `Monetizable` concern for currency handling
- JSONB fields for flexible data (linked_account_ids, milestones)
- Proper enum patterns with validation
- UUID primary keys
- Follows existing Budget/RecurringTransaction patterns

---

### ✅ Phase 2: Savings Rate & Financial Health Metrics (COMPLETED)
**Status:** Merged to main on December 26, 2025

**What Was Implemented:**
- Database table: `financial_snapshots` for point-in-time metrics
- FinancialSnapshot model with calculation logic for 4 core metrics:
  - Savings rate (income - expenses / income)
  - Debt-to-income ratio (monthly debt payments / income)
  - Emergency fund coverage (liquid assets / monthly expenses)
  - Net worth trend (month-over-month change)
- FinancialHealth model for real-time metric calculations
- FinancialSnapshot::Calculator service with complex averaging logic
- FinancialSnapshotJob scheduled monthly (1st of each month at 3 AM)
- FinancialHealthController with show, export (CSV), and recalculate actions
- Complete financial health report page with health score
- Financial health helper with metric status colors and insights
- Comprehensive rake tasks for backfilling historical data
- Full test coverage (30 tests, all passing)

**Key Features:**
- Overall health score (0-100) weighted across 4 metrics
- Historical snapshot storage with monthly granularity
- CSV export functionality for data analysis
- Smart metric thresholds based on financial best practices
- Configurable threshold constants in FinancialHealthThresholds concern
- Automatic estimation of credit card minimum payments
- Multi-month averaging for income/expense stability
- Rich localization support with detailed insights

**Files Changed:** 19 files, 1,777 insertions
- Models: `FinancialSnapshot`, `FinancialHealth`, `FinancialSnapshot::Calculator`
- Controller: `FinancialHealthController`
- Job: `FinancialSnapshotJob`
- Helper: `FinancialHealthHelper`
- Views: Complete financial health report page
- Tests: Comprehensive model, calculator, and controller tests
- Rake tasks: Backfill and current month generation

**Technical Highlights:**
- Uses `Monetizable` concern for currency handling
- JSONB metadata field for flexible data storage
- Compound unique index on family_id + snapshot_date
- Proper decimal precision for percentages and money
- Integration with existing Family#income_statement and #balance_sheet
- Scheduled monthly execution via sidekiq-cron
- Graceful handling of insufficient data

---

### ⏳ Phase 3: Cash Flow Forecasting & Projections (QUEUED)
**Estimated Duration:** 3-4 weeks  
**Complexity:** High  
**Dependencies:** Phase 1 (optional goal integration)

See: [PHASE-3-CASH-FLOW-FORECAST.md](PHASE-3-CASH-FLOW-FORECAST.md)

---

### ⏳ Phase 3: Cash Flow Forecasting & Projections (QUEUED)
**Estimated Duration:** 3-4 weeks  
**Complexity:** High  
**Dependencies:** Phase 1 (optional goal integration)

See: [PHASE-3-CASH-FLOW-FORECAST.md](PHASE-3-CASH-FLOW-FORECAST.md)

---

### ⏳ Phase 4: Notification System & Smart Alerts (QUEUED)
**Estimated Duration:** 2-3 weeks  
**Complexity:** Medium  
**Dependencies:** Phases 1-3 (for complete alert coverage)

See: [PHASE-4-NOTIFICATIONS.md](PHASE-4-NOTIFICATIONS.md)

---

### ⏳ Phase 5: Advanced Investment Analytics (QUEUED)
**Estimated Duration:** 3-4 weeks  
**Complexity:** High  
**Dependencies:** None (enhances existing investment system)

See: [PHASE-5-INVESTMENT-ANALYTICS.md](PHASE-5-INVESTMENT-ANALYTICS.md)

---

### ⏳ Phase 6: Account Organization & Custom Views (QUEUED)
**Estimated Duration:** 2 weeks  
**Complexity:** Low-Medium  
**Dependencies:** None (independent UX enhancement)

See: [PHASE-6-FOLDERS-ORGANIZATION.md](PHASE-6-FOLDERS-ORGANIZATION.md)

---

## Development Guidelines

### Before Starting Any Phase:

1. **Read the detailed phase document completely**
2. **Review existing patterns in codebase:**
   - Model patterns: `Budget`, `RecurringTransaction`, `Category`
   - Controller patterns: `BudgetsController`, `TagsController`
   - ViewComponent patterns: `DS/` and `UI/` namespaces
   - Testing patterns: Minitest with fixtures

3. **Set up your environment:**
   - Ensure Ruby 3.4.7 is active (`ruby -v`)
   - Database is up-to-date (`bin/rails db:migrate`)
   - All existing tests pass (`bin/rails test`)

4. **Create a feature branch:**
   ```bash
   git checkout -b copilot/phase-X-feature-name
   ```

### During Development:

1. **Follow TDD approach:**
   - Write tests first (or alongside code)
   - Run tests frequently: `bin/rails test test/models/your_model_test.rb`
   - Ensure all tests pass before committing

2. **Run linters regularly:**
   ```bash
   bin/rubocop -A  # Auto-fix style issues
   npm run lint:fix  # Fix JS/TS issues
   ```

3. **Check for errors:**
   - Monitor VS Code Problems panel
   - Run `bin/rails db:migrate` in test environment
   - Test in browser during development

4. **Commit atomically:**
   - Small, focused commits
   - Clear commit messages
   - Reference phase in commits: "Phase 2: Add FinancialSnapshot model"

### Before Opening PR:

1. **Run full test suite:** `bin/rails test`
2. **Run linters:** `bin/rubocop && npm run lint`
3. **Run security check:** `bin/brakeman`
4. **Manual testing:** Test core workflows in browser
5. **Update documentation:** Add inline code comments where needed

### Code Review Checklist:

- [ ] Follows existing patterns (Monetizable, Concerns, etc.)
- [ ] Uses UUID primary keys
- [ ] Decimal precision (19, 4) for money fields
- [ ] JSONB for flexible data
- [ ] Proper indexes on foreign keys and query columns
- [ ] Uses `Current.family` scoping in controllers
- [ ] ViewComponents for reusable UI
- [ ] Localization in `config/locales/`
- [ ] Comprehensive test coverage
- [ ] No RuboCop or Brakeman warnings

---

## Architecture Patterns to Follow

### Models:
```ruby
class YourModel < ApplicationRecord
  include Monetizable  # For money fields
  
  belongs_to :family
  
  validates :required_field, presence: true
  enum :status, %w[active inactive].index_by(&:itself), prefix: true
  
  monetize :amount_field
  
  scope :active, -> { where(status: "active") }
  
  # Public methods
  def calculated_value
    # Logic here
  end
  
  private
  
  # Private helper methods
end
```

### Controllers:
```ruby
class YourController < ApplicationController
  before_action :set_resource, only: %i[show edit update destroy]
  
  def index
    @resources = Current.family.your_resources
  end
  
  private
  
  def set_resource
    @resource = Current.family.your_resources.find(params[:id])
  end
  
  def resource_params
    params.require(:your_resource).permit(:field1, :field2)
  end
end
```

### Migrations:
```ruby
class CreateYourTable < ActiveRecord::Migration[7.2]
  def change
    create_table :your_table, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.decimal :amount, precision: 19, scale: 4
      t.jsonb :metadata, default: {}
      t.timestamps
    end
    
    add_index :your_table, [:family_id, :created_at]
  end
end
```

---

## Testing Patterns

### Model Tests:
```ruby
require "test_helper"

class YourModelTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end
  
  test "validates presence of required fields" do
    model = YourModel.new
    assert_not model.valid?
    assert_includes model.errors[:field], "can't be blank"
  end
  
  test "calculates value correctly" do
    model = your_models(:fixture_name)
    assert_equal expected_value, model.calculated_value
  end
end
```

---

## Questions or Issues?

If you encounter problems during implementation:

1. **Check existing patterns:** Search codebase for similar implementations
2. **Review related models:** Look at Budget, Transaction, Account models
3. **Check test failures carefully:** Error messages usually indicate the issue
4. **Run migrations:** Ensure test database is up-to-date
5. **Consult phase documentation:** Detailed specs are in phase markdown files

---

## Next Steps

**Phase 2 is ready to start!** Review [PHASE-2-SAVINGS-METRICS.md](PHASE-2-SAVINGS-METRICS.md) and follow the implementation order specified.

Good luck! 🚀
