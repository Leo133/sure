require "test_helper"

class GoalTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "validates presence of required fields" do
    goal = Goal.new

    assert_not goal.valid?
    assert_includes goal.errors[:name], "can't be blank"
    assert_includes goal.errors[:target_amount], "can't be blank"
    assert_includes goal.errors[:currency], "can't be blank"
  end

  test "validates goal type is one of allowed values" do
    assert_raises(ArgumentError) do
      Goal.new(
        family: @family,
        name: "Test Goal",
        target_amount: 1000,
        currency: "USD",
        goal_type: "invalid_type"
      )
    end
  end

  test "calculates progress percentage correctly" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD",
      current_amount: 250
    )

    assert_equal 25.0, goal.progress_percentage
  end

  test "progress percentage is 0 when current_amount is 0" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD",
      current_amount: 0
    )

    assert_equal 0, goal.progress_percentage
  end

  test "progress percentage caps at 100 when target exceeded" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD",
      current_amount: 1500
    )

    assert_equal 100, goal.progress_percentage
  end

  test "days_remaining returns nil when no target date" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD"
    )

    assert_nil goal.days_remaining
  end

  test "days_remaining returns 0 when target date is past" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD",
      target_date: 1.day.ago.to_date
    )

    assert_equal 0, goal.days_remaining
  end

  test "days_remaining calculates correctly for future date" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD",
      target_date: 30.days.from_now.to_date
    )

    assert_equal 30, goal.days_remaining
  end

  test "on_track returns true when no target date" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD"
    )

    assert goal.on_track?
  end

  test "tracking_status returns completed for completed goals" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD",
      status: "completed"
    )

    assert_equal "completed", goal.tracking_status
  end

  test "creates default milestones on create" do
    goal = @family.goals.create!(
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD"
    )

    assert_equal 4, goal.milestones.count
    assert_equal [25, 50, 75, 100], goal.milestones.map { |m| m["percentage"] }
    assert goal.milestones.all? { |m| m["reached_at"].nil? }
  end

  test "sets start_date to current date on create if not provided" do
    goal = @family.goals.create!(
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD"
    )

    assert_equal Date.current, goal.start_date
  end

  test "required_monthly_contribution calculates correctly" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1200,
      currency: "USD",
      current_amount: 0,
      target_date: 12.months.from_now.to_date
    )

    # Should need approximately 100 per month
    assert_in_delta 100, goal.required_monthly_contribution, 10
  end

  test "required_monthly_contribution returns 0 for completed goals" do
    goal = Goal.new(
      family: @family,
      name: "Test Goal",
      target_amount: 1000,
      currency: "USD",
      status: "completed"
    )

    assert_equal 0, goal.required_monthly_contribution
  end
end
