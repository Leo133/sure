require "test_helper"

class FinancialSnapshotTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @snapshot = financial_snapshots(:basic_snapshot)
  end

  test "validates presence of required fields" do
    snapshot = FinancialSnapshot.new

    assert_not snapshot.valid?
    assert_includes snapshot.errors[:snapshot_date], "can't be blank"
    assert_includes snapshot.errors[:currency], "can't be blank"
    assert_includes snapshot.errors[:family], "must exist"
  end

  test "validates uniqueness of snapshot_date per family" do
    duplicate = FinancialSnapshot.new(
      family: @family,
      snapshot_date: @snapshot.snapshot_date,
      currency: "USD"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:snapshot_date], "has already been taken"
  end

  test "allows same date for different families" do
    other_family = families(:empty)
    snapshot = FinancialSnapshot.new(
      family: other_family,
      snapshot_date: @snapshot.snapshot_date,
      currency: "USD"
    )

    assert snapshot.valid?
  end

  test "savings rate health returns good for rate >= 20" do
    @snapshot.savings_rate = 25

    summary = @snapshot.metrics_summary
    assert_equal :good, summary[:savings_rate][:health_status]
  end

  test "savings rate health returns fair for rate 10-20" do
    @snapshot.savings_rate = 15

    summary = @snapshot.metrics_summary
    assert_equal :fair, summary[:savings_rate][:health_status]
  end

  test "savings rate health returns poor for rate < 10" do
    @snapshot.savings_rate = 5

    summary = @snapshot.metrics_summary
    assert_equal :poor, summary[:savings_rate][:health_status]
  end

  test "debt to income health returns good for ratio < 36" do
    @snapshot.debt_to_income_ratio = 30

    summary = @snapshot.metrics_summary
    assert_equal :good, summary[:debt_to_income_ratio][:health_status]
  end

  test "debt to income health returns fair for ratio 36-43" do
    @snapshot.debt_to_income_ratio = 40

    summary = @snapshot.metrics_summary
    assert_equal :fair, summary[:debt_to_income_ratio][:health_status]
  end

  test "debt to income health returns poor for ratio > 43" do
    @snapshot.debt_to_income_ratio = 50

    summary = @snapshot.metrics_summary
    assert_equal :poor, summary[:debt_to_income_ratio][:health_status]
  end

  test "emergency fund health returns good for 6+ months" do
    @snapshot.emergency_fund_months = 7

    summary = @snapshot.metrics_summary
    assert_equal :good, summary[:emergency_fund_months][:health_status]
  end

  test "emergency fund health returns fair for 3-6 months" do
    @snapshot.emergency_fund_months = 4

    summary = @snapshot.metrics_summary
    assert_equal :fair, summary[:emergency_fund_months][:health_status]
  end

  test "emergency fund health returns poor for < 3 months" do
    @snapshot.emergency_fund_months = 2

    summary = @snapshot.metrics_summary
    assert_equal :poor, summary[:emergency_fund_months][:health_status]
  end

  test "health_score returns weighted average of normalized metrics" do
    @snapshot.savings_rate = 20
    @snapshot.debt_to_income_ratio = 30
    @snapshot.emergency_fund_months = 6

    score = @snapshot.health_score

    assert_not_nil score
    assert score >= 0 && score <= 100
  end

  test "health_score returns nil when no metrics present" do
    snapshot = FinancialSnapshot.new(
      family: families(:empty),  # Use a family with no previous snapshots
      snapshot_date: Date.current,
      currency: "USD",
      savings_rate: nil,
      debt_to_income_ratio: nil,
      emergency_fund_months: nil
    )

    assert_nil snapshot.health_score
  end

  test "comparison_to_previous returns changes from previous snapshot" do
    comparison = @snapshot.comparison_to_previous

    assert_not_nil comparison
    assert comparison.key?(:net_worth_change)
    assert comparison.key?(:savings_rate_change)
    assert comparison.key?(:previous_snapshot)
  end

  test "net_worth_change_percentage calculates correctly" do
    # The basic_snapshot has net_worth of 50000
    # The older_snapshot has net_worth of 48000
    # Change should be approximately (50000-48000)/48000 * 100 = 4.17%
    change = @snapshot.net_worth_change_percentage

    assert_not_nil change
    assert_in_delta 4.17, change, 0.1
  end

  test "recent scope orders by snapshot_date descending" do
    snapshots = @family.financial_snapshots.recent

    assert_equal @snapshot, snapshots.first
  end

  test "last_n_months scope returns snapshots within range" do
    snapshots = @family.financial_snapshots.last_n_months(3)

    assert snapshots.include?(@snapshot)
    assert snapshots.include?(financial_snapshots(:older_snapshot))
  end

  test "metrics_summary returns all metrics with labels and formats" do
    summary = @snapshot.metrics_summary

    assert_equal 4, summary.keys.count
    assert summary[:savings_rate].key?(:value)
    assert summary[:savings_rate].key?(:label)
    assert summary[:savings_rate].key?(:format)
    assert summary[:savings_rate].key?(:health_status)
  end

  test "monetize provides money objects for monetary fields" do
    assert_respond_to @snapshot, :net_worth_money
    assert_respond_to @snapshot, :liquid_assets_money
    assert_respond_to @snapshot, :monthly_income_money

    money = @snapshot.net_worth_money
    assert money.is_a?(Money)
    assert_equal @snapshot.currency, money.currency.iso_code
  end
end
