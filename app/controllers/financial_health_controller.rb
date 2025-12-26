class FinancialHealthController < ApplicationController
  before_action :set_financial_health

  def show
    @current_metrics = @financial_health.metrics_with_status
    @health_score = @financial_health.health_score
    @latest_snapshot = Current.family.latest_financial_snapshot
    @historical_snapshots = Current.family.financial_snapshots.recent.limit(12)
  end

  def export
    @snapshots = Current.family.financial_snapshots.recent

    respond_to do |format|
      format.csv do
        send_data generate_csv(@snapshots),
                  filename: "financial_health_#{Date.current}.csv",
                  type: "text/csv"
      end
    end
  end

  def recalculate
    FinancialSnapshot.calculate_for_family!(Current.family, date: Date.current.last_month.end_of_month)
    redirect_to financial_health_path, notice: t(".recalculated")
  end

  private

    def set_financial_health
      @financial_health = Current.family.financial_health
    end

    def generate_csv(snapshots)
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [
          "Date",
          "Net Worth",
          "Liquid Assets",
          "Total Debt",
          "Monthly Income",
          "Monthly Expenses",
          "Monthly Savings",
          "Savings Rate (%)",
          "Debt-to-Income (%)",
          "Emergency Fund (months)"
        ]

        snapshots.each do |snapshot|
          csv << [
            snapshot.snapshot_date.to_s,
            snapshot.net_worth&.to_f,
            snapshot.liquid_assets&.to_f,
            snapshot.total_debt&.to_f,
            snapshot.monthly_income&.to_f,
            snapshot.monthly_expenses&.to_f,
            snapshot.monthly_savings&.to_f,
            snapshot.savings_rate&.to_f,
            snapshot.debt_to_income_ratio&.to_f,
            snapshot.emergency_fund_months&.to_f
          ]
        end
      end
    end
end
