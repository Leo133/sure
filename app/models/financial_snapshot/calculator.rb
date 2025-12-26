class FinancialSnapshot::Calculator
  attr_reader :family, :date

  def initialize(family, date)
    @family = family
    @date = date
  end

  def calculate_all
    {
      net_worth: calculate_net_worth,
      liquid_assets: calculate_liquid_assets,
      total_debt: calculate_total_debt,
      monthly_income: calculate_monthly_income,
      monthly_expenses: calculate_monthly_expenses,
      monthly_savings: calculate_monthly_savings,
      savings_rate: calculate_savings_rate,
      debt_to_income_ratio: calculate_debt_to_income_ratio,
      emergency_fund_months: calculate_emergency_fund_months,
      metadata: build_metadata
    }
  end

  # Net worth from balance sheet
  def calculate_net_worth
    family.balance_sheet.net_worth.to_d
  end

  # Liquid assets: checking + savings accounts only
  def calculate_liquid_assets
    liquid_accounts.sum(&:balance).to_d
  end

  # Total debt: sum of all liability account balances
  def calculate_total_debt
    family.accounts
          .active
          .joins(:accountable)
          .where(classification: "liability")
          .sum(:balance).to_d
  end

  # Monthly income for the snapshot month
  def calculate_monthly_income
    period = Period.custom(start_date: date.beginning_of_month, end_date: date.end_of_month)
    family.income_statement.income_totals(period: period).total.to_d.abs
  end

  # Monthly expenses for the snapshot month
  def calculate_monthly_expenses
    period = Period.custom(start_date: date.beginning_of_month, end_date: date.end_of_month)
    family.income_statement.expense_totals(period: period).total.to_d.abs
  end

  # Monthly savings (income - expenses)
  def calculate_monthly_savings
    income = calculate_monthly_income
    expenses = calculate_monthly_expenses
    [ income - expenses, 0 ].max
  end

  # Savings rate: (income - expenses) / income * 100
  def calculate_savings_rate
    income = calculate_monthly_income
    return nil if income.nil? || income.zero?

    expenses = calculate_monthly_expenses
    savings = income - expenses

    ((savings / income) * 100).round(2)
  end

  # Debt-to-income ratio: monthly debt payments / monthly income * 100
  def calculate_debt_to_income_ratio
    income = average_monthly_income(months: 3)
    return nil if income.nil? || income.zero?

    monthly_debt_payments = estimate_monthly_debt_payments
    ((monthly_debt_payments / income) * 100).round(2)
  end

  # Emergency fund: liquid assets / average monthly expenses
  def calculate_emergency_fund_months
    liquid = calculate_liquid_assets
    avg_expenses = average_monthly_expenses(months: 6)

    return nil if avg_expenses.nil? || avg_expenses.zero?

    (liquid / avg_expenses).round(2)
  end

  private

    # Get depository (checking/savings) accounts as liquid assets
    def liquid_accounts
      @liquid_accounts ||= family.accounts
                                  .active
                                  .joins("INNER JOIN depositories ON depositories.id = accounts.accountable_id AND accounts.accountable_type = 'Depository'")
    end

    # Calculate average monthly income over the past N months
    def average_monthly_income(months:)
      total = 0
      months_with_data = 0

      months.times do |i|
        month_date = date - (i + 1).months
        period = Period.custom(start_date: month_date.beginning_of_month, end_date: month_date.end_of_month)
        income = family.income_statement.income_totals(period: period).total.to_d.abs

        if income > 0
          total += income
          months_with_data += 1
        end
      end

      return 0 if months_with_data.zero?

      total / months_with_data
    end

    # Calculate average monthly expenses over the past N months
    def average_monthly_expenses(months:)
      total = 0
      months_with_data = 0

      months.times do |i|
        month_date = date - (i + 1).months
        period = Period.custom(start_date: month_date.beginning_of_month, end_date: month_date.end_of_month)
        expenses = family.income_statement.expense_totals(period: period).total.to_d.abs

        if expenses > 0
          total += expenses
          months_with_data += 1
        end
      end

      return 0 if months_with_data.zero?

      total / months_with_data
    end

    # Estimate monthly debt payments from loan and credit card accounts
    def estimate_monthly_debt_payments
      loan_payments = estimate_loan_payments
      credit_card_payments = estimate_credit_card_payments
      loan_payments + credit_card_payments
    end

    # Estimate loan payments from loan accounts
    def estimate_loan_payments
      family.accounts
            .active
            .joins("INNER JOIN loans ON loans.id = accounts.accountable_id AND accounts.accountable_type = 'Loan'")
            .sum("COALESCE(loans.minimum_payment, 0)").to_d
    end

    # Estimate credit card payments (minimum payment based on balance)
    def estimate_credit_card_payments
      credit_card_balances = family.accounts
                                    .active
                                    .joins("INNER JOIN credit_cards ON credit_cards.id = accounts.accountable_id AND accounts.accountable_type = 'CreditCard'")
                                    .sum(:balance).to_d

      # Assume minimum payment is approximately 2% of balance or $25, whichever is greater
      [ credit_card_balances * 0.02, 25 ].max
    end

    # Build additional metadata
    def build_metadata
      {
        calculated_at: Time.current.iso8601,
        month_name: date.strftime("%B %Y"),
        accounts_included: {
          liquid_count: liquid_accounts.count,
          total_count: family.accounts.active.count
        }
      }
    end
end
