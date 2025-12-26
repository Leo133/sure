require "test_helper"

class FinancialSnapshot::CalculatorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @calculator = FinancialSnapshot::Calculator.new(@family, Date.current)
  end

  test "calculate_all returns all metrics" do
    result = @calculator.calculate_all

    assert result.key?(:net_worth)
    assert result.key?(:liquid_assets)
    assert result.key?(:total_debt)
    assert result.key?(:monthly_income)
    assert result.key?(:monthly_expenses)
    assert result.key?(:monthly_savings)
    assert result.key?(:savings_rate)
    assert result.key?(:debt_to_income_ratio)
    assert result.key?(:emergency_fund_months)
    assert result.key?(:metadata)
  end

  test "calculate_net_worth returns balance sheet net worth" do
    net_worth = @calculator.calculate_net_worth

    assert_kind_of Numeric, net_worth
  end

  test "calculate_liquid_assets returns sum of depository accounts" do
    liquid_assets = @calculator.calculate_liquid_assets

    assert_kind_of Numeric, liquid_assets
    assert liquid_assets >= 0
  end

  test "calculate_total_debt returns sum of liability balances" do
    total_debt = @calculator.calculate_total_debt

    assert_kind_of Numeric, total_debt
    assert total_debt >= 0
  end

  test "calculate_savings_rate returns nil when no income" do
    # Mock a family with no income
    calculator = FinancialSnapshot::Calculator.new(families(:empty), Date.current)
    savings_rate = calculator.calculate_savings_rate

    # Empty family has no income, so should return nil
    assert_nil savings_rate
  end

  test "calculate_monthly_savings is non-negative" do
    savings = @calculator.calculate_monthly_savings

    assert_kind_of Numeric, savings
    assert savings >= 0
  end

  test "metadata includes calculated_at and month_name" do
    result = @calculator.calculate_all
    metadata = result[:metadata]

    assert metadata[:calculated_at].present?
    assert metadata[:month_name].present?
    assert metadata[:accounts_included].present?
  end
end
