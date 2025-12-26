class CashFlowController < ApplicationController
  before_action :set_projection_service

  def show
    @view_mode = params[:view] || "month"
    @start_date = parse_date(params[:start_date]) || Date.current.beginning_of_month
    @end_date = calculate_end_date(@start_date, @view_mode)

    @projection = @projection_service.generate_projection
    @balance_curve = @projection[:balance_curve]
    @alerts = @projection[:alerts]
    @summary = @projection[:summary]

    # Group projections by date for calendar view
    @projections_by_date = @projection[:projections].group_by { |p| p[:date] }
  end

  def balance_chart
    projection = @projection_service.generate_projection
    curve = projection[:balance_curve]

    render json: {
      labels: curve.map { |p| p[:date].to_s },
      datasets: [
        {
          label: t(".projected_balance"),
          data: curve.map { |p| p[:balance].to_f.round(2) },
          borderColor: "rgb(59, 130, 246)",
          backgroundColor: "rgba(59, 130, 246, 0.1)",
          fill: true,
          tension: 0.4
        }
      ],
      confidence: curve.map { |p| p[:confidence] },
      alerts: projection[:alerts]
    }
  end

  def day_details
    date = Date.parse(params[:date])
    @projections = @projection_service.projections_for_date(date)
    @date = date

    respond_to do |format|
      format.html { render partial: "day_details", locals: { projections: @projections, date: @date } }
      format.turbo_stream
    end
  end

  def scenario
    scenario_params = params.require(:scenario).permit(:type, :amount, :date, :description, :recurring_transaction_id)

    result = case scenario_params[:type]
    when "add_transaction"
      @projection_service.scenario_with_transaction(
        amount: scenario_params[:amount].to_d,
        date: Date.parse(scenario_params[:date]),
        type: scenario_params[:amount].to_d < 0 ? :income : :expense,
        description: scenario_params[:description] || t(".hypothetical_transaction")
      )
    when "remove_recurring"
      @projection_service.scenario_without_recurring(scenario_params[:recurring_transaction_id])
    else
      @projection_service.balance_curve
    end

    render json: {
      original: @projection_service.balance_curve,
      scenario: result,
      comparison: generate_comparison(@projection_service.balance_curve, result)
    }
  end

  def upcoming
    @days = (params[:days] || 7).to_i
    @projection_service = CashFlow::ProjectionService.new(
      Current.family,
      start_date: Date.current,
      end_date: @days.days.from_now.to_date
    )

    @projection = @projection_service.generate_projection
    @upcoming_projections = @projection[:projections].first(10)
    @alerts = @projection[:alerts]

    respond_to do |format|
      format.html { render partial: "upcoming_widget" }
      format.json { render json: { projections: @upcoming_projections, alerts: @alerts } }
    end
  end

  private

    def set_projection_service
      account_ids = params[:account_ids].presence
      start_date = parse_date(params[:start_date]) || Date.current
      end_date = parse_date(params[:end_date]) || 90.days.from_now.to_date

      @projection_service = CashFlow::ProjectionService.new(
        Current.family,
        start_date: start_date,
        end_date: end_date,
        account_ids: account_ids
      )
    end

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end

    def calculate_end_date(start_date, view_mode)
      case view_mode
      when "day"
        start_date
      when "week"
        start_date + 6.days
      when "month"
        start_date.end_of_month
      else
        start_date + 30.days
      end
    end

    def generate_comparison(original, scenario)
      return {} if original.empty? || scenario.empty?

      original_end = original.last[:balance].to_f
      scenario_end = scenario.last[:balance].to_f

      {
        original_ending_balance: original_end,
        scenario_ending_balance: scenario_end,
        difference: (scenario_end - original_end).round(2),
        impact_description: if scenario_end > original_end
          t(".positive_impact", amount: (scenario_end - original_end).abs.round(2))
        elsif scenario_end < original_end
          t(".negative_impact", amount: (original_end - scenario_end).abs.round(2))
        else
          t(".no_impact")
        end
      }
    end
end
