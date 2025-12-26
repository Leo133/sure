require "test_helper"

class FinancialHealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "should get show" do
    get financial_health_url
    assert_response :success
  end

  test "should export csv" do
    get export_financial_health_url(format: :csv)
    assert_response :success
    assert_equal "text/csv", response.media_type
  end

  test "should recalculate" do
    post recalculate_financial_health_url
    assert_redirected_to financial_health_url
  end
end
