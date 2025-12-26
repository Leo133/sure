require "test_helper"

class CashFlowControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "show renders the cash flow page" do
    get cash_flow_path

    assert_response :success
    assert_select "h1", text: /Cash Flow Forecast/
  end

  test "show respects view mode parameter" do
    get cash_flow_path(view: "week")
    assert_response :success

    get cash_flow_path(view: "month")
    assert_response :success
  end

  test "show respects start_date parameter" do
    get cash_flow_path(start_date: "2025-01-15")
    assert_response :success
  end

  test "balance_chart returns json" do
    get balance_chart_cash_flow_path, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("labels")
    assert json.key?("datasets")
    assert json.key?("confidence")
    assert json.key?("alerts")
  end

  test "day_details returns turbo stream" do
    date = 5.days.from_now.to_date.to_s

    get day_cash_flow_path(date: date), as: :turbo_stream

    assert_response :success
  end

  test "day_details returns html partial" do
    date = 5.days.from_now.to_date.to_s

    get day_cash_flow_path(date: date), as: :html

    assert_response :success
  end

  test "scenario calculates what-if for new transaction" do
    post scenario_cash_flow_path, params: {
      scenario: {
        type: "add_transaction",
        amount: "500",
        date: 10.days.from_now.to_date.to_s,
        description: "Test expense"
      }
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("original")
    assert json.key?("scenario")
    assert json.key?("comparison")
  end

  test "upcoming returns partial with projections" do
    get upcoming_cash_flow_path

    assert_response :success
  end

  test "upcoming respects days parameter" do
    get upcoming_cash_flow_path(days: 14)

    assert_response :success
  end

  test "upcoming returns json format" do
    get upcoming_cash_flow_path, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("projections")
    assert json.key?("alerts")
  end
end
