class FinancialSnapshot < ApplicationRecord
  include Monetizable
  include FinancialHealthThresholds

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
    scores = []
    weights = []

    if savings_rate.present?
      scores << normalize_savings_rate
      weights << SAVINGS_RATE_WEIGHT
    end

    if debt_to_income_ratio.present?
      scores << normalize_debt_to_income
      weights << DTI_WEIGHT
    end

    if emergency_fund_months.present?
      scores << normalize_emergency_fund
      weights << EMERGENCY_FUND_WEIGHT
    end

    if net_worth_change_percentage.present?
      scores << normalize_net_worth_trend
      weights << NET_WORTH_TREND_WEIGHT
    end

    return nil if scores.empty?

    # Calculate weighted average
    weighted_sum = scores.zip(weights).sum { |score, weight| score * weight }
    total_weight = weights.sum

    ((weighted_sum / total_weight) * MAX_HEALTH_SCORE).round
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

      if savings_rate >= EXCELLENT_SAVINGS_RATE
        :good
      elsif savings_rate >= GOOD_SAVINGS_RATE
        :fair
      else
        :poor
      end
    end

    def debt_to_income_health
      return :unknown unless debt_to_income_ratio.present?

      if debt_to_income_ratio < HEALTHY_DTI_THRESHOLD
        :good
      elsif debt_to_income_ratio <= MANAGEABLE_DTI_THRESHOLD
        :fair
      else
        :poor
      end
    end

    def emergency_fund_health
      return :unknown unless emergency_fund_months.present?

      if emergency_fund_months >= STRONG_EMERGENCY_FUND_MONTHS
        :good
      elsif emergency_fund_months >= SOLID_EMERGENCY_FUND_MONTHS
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
      elsif change >= STABLE_NET_WORTH_THRESHOLD
        :fair
      else
        :poor
      end
    end

    # Normalize metrics to 0-1 scale for health score calculation
    def normalize_savings_rate
      return 0 unless savings_rate.present?

      [ [ savings_rate / EXCELLENT_SAVINGS_RATE, 1.0 ].min, 0 ].max
    end

    def normalize_debt_to_income
      return 0 unless debt_to_income_ratio.present?

      if debt_to_income_ratio <= HEALTHY_DTI_THRESHOLD
        1.0
      elsif debt_to_income_ratio >= HIGH_RISK_DTI_THRESHOLD
        0.0
      else
        1.0 - ((debt_to_income_ratio - HEALTHY_DTI_THRESHOLD) / DTI_NORMALIZATION_RANGE)
      end
    end

    def normalize_emergency_fund
      return 0 unless emergency_fund_months.present?

      [ [ emergency_fund_months / STRONG_EMERGENCY_FUND_MONTHS, 1.0 ].min, 0 ].max
    end

    def normalize_net_worth_trend
      change = net_worth_change_percentage
      return 0.5 unless change.present? # Neutral if no data

      if change >= EXCELLENT_NET_WORTH_GROWTH
        1.0
      elsif change <= POOR_NET_WORTH_DECLINE
        0.0
      else
        0.5 + (change / NORMALIZATION_DIVISOR)
      end
    end
end
