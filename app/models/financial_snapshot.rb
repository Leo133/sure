class FinancialSnapshot < ApplicationRecord
  include Monetizable

  belongs_to :family

  validates :snapshot_date, presence: true, uniqueness: { scope: :family_id }
  validates :currency, presence: true

  monetize :net_worth, :liquid_assets, :total_debt,
           :monthly_income, :monthly_expenses, :monthly_savings

  scope :recent, -> { order(snapshot_date: :desc) }
  scope :for_period, ->(start_date, end_date) { where(snapshot_date: start_date..end_date) }
  scope :last_n_months, ->(n) { where("snapshot_date >= ?", n.months.ago.beginning_of_month) }

  class << self
    # Generate a snapshot for a family at a specific date (defaults to end of previous month)
    def calculate_for_family!(family, date: nil)
      date ||= Date.current.last_month.end_of_month

      # Don't create duplicate snapshots
      existing = find_by(family: family, snapshot_date: date)
      return existing if existing

      calculator = Calculator.new(family, date)
      metrics = calculator.calculate_all

      create!(
        family: family,
        snapshot_date: date,
        currency: family.currency,
        **metrics
      )
    end
  end

  # Get metrics as a summary hash for display
  def metrics_summary
    {
      savings_rate: {
        value: savings_rate,
        label: "Savings Rate",
        format: :percentage,
        health_status: savings_rate_health
      },
      debt_to_income_ratio: {
        value: debt_to_income_ratio,
        label: "Debt-to-Income",
        format: :percentage,
        health_status: debt_to_income_health
      },
      emergency_fund_months: {
        value: emergency_fund_months,
        label: "Emergency Fund",
        format: :months,
        health_status: emergency_fund_health
      },
      net_worth_change: {
        value: net_worth_change_percentage,
        label: "Net Worth Change",
        format: :percentage,
        health_status: net_worth_trend_health
      }
    }
  end

  # Calculate overall health score (0-100)
  def health_score
    # Weight metrics: 30% savings rate, 30% DTI, 25% emergency fund, 15% net worth trend
    scores = []

    scores << (normalize_savings_rate * 0.30) if savings_rate.present?
    scores << (normalize_debt_to_income * 0.30) if debt_to_income_ratio.present?
    scores << (normalize_emergency_fund * 0.25) if emergency_fund_months.present?
    scores << (normalize_net_worth_trend * 0.15) if net_worth_change_percentage.present?

    return nil if scores.empty?

    # Normalize by actual weights used (in case some metrics are missing)
    total_weight = 0.30 + 0.30 + 0.25 + 0.15
    used_weight = scores.sum { |_| 1.0 } # Count of present metrics
    adjustment = total_weight / (used_weight * (total_weight / 4))

    (scores.sum * adjustment * 100).round
  end

  # Get change from previous month's snapshot
  def comparison_to_previous
    previous_snapshot = family.financial_snapshots
                              .where("snapshot_date < ?", snapshot_date)
                              .order(snapshot_date: :desc)
                              .first

    return nil unless previous_snapshot

    {
      net_worth_change: net_worth.to_f - previous_snapshot.net_worth.to_f,
      savings_rate_change: (savings_rate || 0) - (previous_snapshot.savings_rate || 0),
      debt_to_income_change: (debt_to_income_ratio || 0) - (previous_snapshot.debt_to_income_ratio || 0),
      emergency_fund_change: (emergency_fund_months || 0) - (previous_snapshot.emergency_fund_months || 0),
      previous_snapshot: previous_snapshot
    }
  end

  # Calculate net worth percentage change from previous month
  def net_worth_change_percentage
    previous = family.financial_snapshots
                     .where("snapshot_date < ?", snapshot_date)
                     .order(snapshot_date: :desc)
                     .first

    return nil unless previous&.net_worth.present? && previous.net_worth != 0

    ((net_worth.to_f - previous.net_worth.to_f) / previous.net_worth.to_f.abs * 100).round(2)
  end

  private

    # Health status helpers (returns :good, :fair, :poor)
    def savings_rate_health
      return :unknown unless savings_rate.present?

      if savings_rate >= 20
        :good
      elsif savings_rate >= 10
        :fair
      else
        :poor
      end
    end

    def debt_to_income_health
      return :unknown unless debt_to_income_ratio.present?

      if debt_to_income_ratio < 36
        :good
      elsif debt_to_income_ratio <= 43
        :fair
      else
        :poor
      end
    end

    def emergency_fund_health
      return :unknown unless emergency_fund_months.present?

      if emergency_fund_months >= 6
        :good
      elsif emergency_fund_months >= 3
        :fair
      else
        :poor
      end
    end

    def net_worth_trend_health
      change = net_worth_change_percentage
      return :unknown unless change.present?

      if change > 0
        :good
      elsif change >= -5
        :fair
      else
        :poor
      end
    end

    # Normalize metrics to 0-1 scale for health score calculation
    def normalize_savings_rate
      return 0 unless savings_rate.present?

      # 20%+ is excellent (1.0), 0% or negative is 0
      [ [ savings_rate / 20.0, 1.0 ].min, 0 ].max
    end

    def normalize_debt_to_income
      return 0 unless debt_to_income_ratio.present?

      # <36% is excellent (1.0), >50% is poor (0)
      if debt_to_income_ratio <= 36
        1.0
      elsif debt_to_income_ratio >= 50
        0.0
      else
        1.0 - ((debt_to_income_ratio - 36) / 14.0)
      end
    end

    def normalize_emergency_fund
      return 0 unless emergency_fund_months.present?

      # 6+ months is excellent (1.0), 0 is poor (0)
      [ [ emergency_fund_months / 6.0, 1.0 ].min, 0 ].max
    end

    def normalize_net_worth_trend
      change = net_worth_change_percentage
      return 0.5 unless change.present? # Neutral if no data

      # +10% is excellent (1.0), -10% is poor (0), 0% is 0.5
      if change >= 10
        1.0
      elsif change <= -10
        0.0
      else
        0.5 + (change / 20.0)
      end
    end
end
