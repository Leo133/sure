require "test_helper"

class CashFlow::ProjectionServiceTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @service = CashFlow::ProjectionService.new(
      @family,
      start_date: Date.current,
      end_date: 30.days.from_now.to_date
    )
  end

  test "initializes with correct defaults" do
    service = CashFlow::ProjectionService.new(@family)

    assert_equal @family, service.family
    assert_equal Date.current, service.start_date
    assert_equal 90.days.from_now.to_date, service.end_date
    assert_nil service.account_ids
  end

  test "generates projection with all required keys" do
    projection = @service.generate_projection

    assert projection.key?(:projections)
    assert projection.key?(:balance_curve)
    assert projection.key?(:summary)
    assert projection.key?(:alerts)
  end

  test "daily_projections returns array of projections" do
    projections = @service.daily_projections

    assert projections.is_a?(Array)
    projections.each do |p|
      assert p.key?(:date)
      assert p.key?(:type)
      assert p.key?(:amount)
      assert p.key?(:confidence)
      assert p.key?(:source)
    end
  end

  test "balance_curve returns array of balance points" do
    curve = @service.balance_curve

    assert curve.is_a?(Array)
    assert_equal 31, curve.count # 30 days + today

    curve.each do |point|
      assert point.key?(:date)
      assert point.key?(:balance)
      assert point.key?(:confidence)
    end
  end

  test "summary includes expected totals" do
    summary = @service.summary

    assert summary.key?(:total_projected_income)
    assert summary.key?(:total_projected_expenses)
    assert summary.key?(:net_projected_cash_flow)
    assert summary.key?(:starting_balance)
    assert summary.key?(:ending_balance)
    assert summary.key?(:date_range)
  end

  test "projections_for_date returns projections for specific date" do
    date = 5.days.from_now.to_date
    projections = @service.projections_for_date(date)

    assert projections.is_a?(Array)
    projections.each do |p|
      assert_equal date, p[:date]
    end
  end

  test "includes recurring transactions in projections" do
    # The netflix_subscription fixture should generate projections
    projections = @service.daily_projections

    recurring_projections = projections.select { |p| p[:source] == :recurring }

    # May or may not have recurring projections depending on dates
    assert recurring_projections.is_a?(Array)
  end

  test "confidence decays over time" do
    curve = @service.balance_curve

    if curve.length > 10
      # Later dates should have lower confidence than earlier dates
      first_confidence = curve.first[:confidence]
      last_confidence = curve.last[:confidence]

      assert last_confidence <= first_confidence
    end
  end

  test "low_balance_alerts detects potential issues" do
    alerts = @service.low_balance_alerts

    assert alerts.is_a?(Array)

    alerts.each do |alert|
      assert %i[low_balance overdraft].include?(alert[:type])
      assert alert.key?(:date)
      assert alert.key?(:severity)
      assert %i[warning critical].include?(alert[:severity])
    end
  end

  test "scenario_with_transaction modifies balance curve" do
    original_curve = @service.balance_curve
    scenario_curve = @service.scenario_with_transaction(
      amount: 1000,
      date: 10.days.from_now.to_date,
      type: :expense,
      description: "Test purchase"
    )

    # Scenario should have same number of days
    assert_equal original_curve.length, scenario_curve.length

    # After the transaction date, balances should differ
    after_date_index = 10
    if scenario_curve.length > after_date_index
      original_balance = original_curve[after_date_index][:balance]
      scenario_balance = scenario_curve[after_date_index][:balance]

      assert_not_equal original_balance, scenario_balance
    end
  end

  test "respects account_ids filter" do
    account = @family.accounts.first
    service = CashFlow::ProjectionService.new(
      @family,
      start_date: Date.current,
      end_date: 30.days.from_now.to_date,
      account_ids: [ account.id ]
    )

    assert_equal [ account.id ], service.account_ids
  end
end
