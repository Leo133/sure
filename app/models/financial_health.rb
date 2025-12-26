class FinancialHealth
  include Monetizable
  include FinancialHealthThresholds

  monetize :liquid_assets, :monthly_income, :monthly_expenses

  attr_reader :family

  def initialize(family)
    @family = family
  end

  def currency
    family.currency
  end

  # Current savings rate for a given period
  def current_savings_rate(period: Period.current_month)
    income = income_for_period(period)
    return nil if income.nil? || income.zero?

    expenses = expenses_for_period(period)
    savings = income - expenses

    ((savings / income) * 100).round(2)
  end

  # Current debt-to-income ratio
  def current_debt_to_income_ratio
    income = average_monthly_income
    return nil if income.nil? || income.zero?

    monthly_debt_payments = estimated_monthly_debt_payments
    ((monthly_debt_payments / income) * 100).round(2)
  end

  # Emergency fund coverage in months
  def emergency_fund_coverage
    liquid = liquid_assets
    avg_expenses = average_monthly_expenses

    return nil if avg_expenses.nil? || avg_expenses.zero?

    (liquid / avg_expenses).round(2)
  end

  # Net worth change from previous month
  def net_worth_change(period: :month)
    current_net_worth = family.balance_sheet.net_worth.to_d
    previous_net_worth = calculate_previous_net_worth(period)

    return nil if previous_net_worth.nil? || previous_net_worth.zero?

    {
      amount: current_net_worth - previous_net_worth,
      percentage: ((current_net_worth - previous_net_worth) / previous_net_worth.abs * 100).round(2)
    }
  end

  # Current liquid assets (checking + savings)
  def liquid_assets
    family.accounts
          .active
          .joins("INNER JOIN depositories ON depositories.id = accounts.accountable_id AND accounts.accountable_type = 'Depository'")
          .sum(:balance).to_d
  end

  # Current month's income
  def monthly_income(period: Period.current_month)
    income_for_period(period)
  end

  # Current month's expenses
  def monthly_expenses(period: Period.current_month)
    expenses_for_period(period)
  end

  # Overall health score (0-100) based on current metrics
  def health_score
    scores = []
    weights = []

    if (sr = current_savings_rate).present?
      scores << normalize_savings_rate(sr)
      weights << SAVINGS_RATE_WEIGHT
    end

    if (dti = current_debt_to_income_ratio).present?
      scores << normalize_debt_to_income(dti)
      weights << DTI_WEIGHT
    end

    if (ef = emergency_fund_coverage).present?
      scores << normalize_emergency_fund(ef)
      weights << EMERGENCY_FUND_WEIGHT
    end

    if (nw = net_worth_change).present?
      scores << normalize_net_worth_trend(nw[:percentage])
      weights << NET_WORTH_TREND_WEIGHT
    end

    return nil if scores.empty?

    weighted_sum = scores.zip(weights).sum { |score, weight| score * weight }
    total_weight = weights.sum

    ((weighted_sum / total_weight) * MAX_HEALTH_SCORE).round
  end

  # Get summary of all metrics
  def summary
    {
      savings_rate: current_savings_rate,
      debt_to_income_ratio: current_debt_to_income_ratio,
      emergency_fund_months: emergency_fund_coverage,
      net_worth_change: net_worth_change,
      health_score: health_score
    }
  end

  # Get health status for each metric
  def metrics_with_status
    {
      savings_rate: {
        value: current_savings_rate,
        status: savings_rate_status(current_savings_rate),
        label: "Savings Rate"
      },
      debt_to_income: {
        value: current_debt_to_income_ratio,
        status: debt_to_income_status(current_debt_to_income_ratio),
        label: "Debt-to-Income"
      },
      emergency_fund: {
        value: emergency_fund_coverage,
        status: emergency_fund_status(emergency_fund_coverage),
        label: "Emergency Fund"
      },
      net_worth_trend: {
        value: net_worth_change,
        status: net_worth_status(net_worth_change),
        label: "Net Worth Trend"
      }
    }
  end

  private

    def income_for_period(period)
      family.income_statement.income_totals(period: period).total.to_d.abs
    end

    def expenses_for_period(period)
      family.income_statement.expense_totals(period: period).total.to_d.abs
    end

    def average_monthly_income(months: 3)
      total = 0
      months_with_data = 0

      months.times do |i|
        month_date = Date.current - (i + 1).months
        period = Period.custom(start_date: month_date.beginning_of_month, end_date: month_date.end_of_month)
        income = income_for_period(period)

        if income > 0
          total += income
          months_with_data += 1
        end
      end

      return 0 if months_with_data.zero?

      total / months_with_data
    end

    def average_monthly_expenses(months: 6)
      total = 0
      months_with_data = 0

      months.times do |i|
        month_date = Date.current - (i + 1).months
        period = Period.custom(start_date: month_date.beginning_of_month, end_date: month_date.end_of_month)
        expenses = expenses_for_period(period)

        if expenses > 0
          total += expenses
          months_with_data += 1
        end
      end

      return 0 if months_with_data.zero?

      total / months_with_data
    end

    def estimated_monthly_debt_payments
      loan_payments + credit_card_payments
    end

    def loan_payments
      family.accounts
            .active
            .joins("INNER JOIN loans ON loans.id = accounts.accountable_id AND accounts.accountable_type = 'Loan'")
            .sum("COALESCE(loans.minimum_payment, 0)").to_d
    end

    def credit_card_payments
      balance = family.accounts
                      .active
                      .joins("INNER JOIN credit_cards ON credit_cards.id = accounts.accountable_id AND accounts.accountable_type = 'CreditCard'")
                      .sum(:balance).to_d

      [ balance * CREDIT_CARD_MIN_PAYMENT_RATE, CREDIT_CARD_MIN_PAYMENT_FLOOR ].max
    end

    def calculate_previous_net_worth(period)
      # Use historical snapshot if available, otherwise estimate from current data
      snapshot = family.financial_snapshots
                       .where("snapshot_date < ?", Date.current)
                       .order(snapshot_date: :desc)
                       .first

      snapshot&.net_worth
    end

    # Status helpers
    def savings_rate_status(rate)
      return :unknown unless rate.present?

      if rate >= EXCELLENT_SAVINGS_RATE
        :good
      elsif rate >= GOOD_SAVINGS_RATE
        :fair
      else
        :poor
      end
    end

    def debt_to_income_status(ratio)
      return :unknown unless ratio.present?

      if ratio < HEALTHY_DTI_THRESHOLD
        :good
      elsif ratio <= MANAGEABLE_DTI_THRESHOLD
        :fair
      else
        :poor
      end
    end

    def emergency_fund_status(months)
      return :unknown unless months.present?

      if months >= STRONG_EMERGENCY_FUND_MONTHS
        :good
      elsif months >= SOLID_EMERGENCY_FUND_MONTHS
        :fair
      else
        :poor
      end
    end

    def net_worth_status(change)
      return :unknown unless change.present?

      if change[:percentage] > 0
        :good
      elsif change[:percentage] >= STABLE_NET_WORTH_THRESHOLD
        :fair
      else
        :poor
      end
    end

    # Normalization helpers for health score
    def normalize_savings_rate(rate)
      return 0 unless rate.present?

      [ [ rate / EXCELLENT_SAVINGS_RATE, 1.0 ].min, 0 ].max
    end

    def normalize_debt_to_income(ratio)
      return 0 unless ratio.present?

      if ratio <= HEALTHY_DTI_THRESHOLD
        1.0
      elsif ratio >= HIGH_RISK_DTI_THRESHOLD
        0.0
      else
        1.0 - ((ratio - HEALTHY_DTI_THRESHOLD) / DTI_NORMALIZATION_RANGE)
      end
    end

    def normalize_emergency_fund(months)
      return 0 unless months.present?

      [ [ months / STRONG_EMERGENCY_FUND_MONTHS, 1.0 ].min, 0 ].max
    end

    def normalize_net_worth_trend(percentage)
      return 0.5 unless percentage.present?

      if percentage >= EXCELLENT_NET_WORTH_GROWTH
        1.0
      elsif percentage <= POOR_NET_WORTH_DECLINE
        0.0
      else
        0.5 + (percentage / NORMALIZATION_DIVISOR)
      end
    end
end
