module FinancialHealthHelper
  def health_score_color(score)
    return "text-subdued" if score.nil?

    if score >= 75
      "text-success"
    elsif score >= 50
      "text-warning"
    else
      "text-destructive"
    end
  end

  def health_score_badge_class(score)
    return "bg-surface-inset text-subdued" if score.nil?

    if score >= 75
      "bg-success/10 text-success"
    elsif score >= 50
      "bg-warning/10 text-warning"
    else
      "bg-destructive/10 text-destructive"
    end
  end

  def health_score_label(score)
    return I18n.t("financial_health.show.unknown") if score.nil?

    if score >= 75
      I18n.t("financial_health.show.excellent")
    elsif score >= 50
      I18n.t("financial_health.show.good")
    elsif score >= 25
      I18n.t("financial_health.show.fair")
    else
      I18n.t("financial_health.show.needs_attention")
    end
  end

  def metric_status_color(status)
    case status
    when :good
      "text-success"
    when :fair
      "text-warning"
    when :poor
      "text-destructive"
    else
      "text-subdued"
    end
  end

  def insight_for_metrics(metrics)
    insights = []

    # Savings rate insight
    if metrics[:savings_rate][:value].present?
      insights << savings_rate_insight(metrics[:savings_rate][:value])
    end

    # Debt-to-income insight
    if metrics[:debt_to_income][:value].present?
      insights << debt_to_income_insight(metrics[:debt_to_income][:value])
    end

    # Emergency fund insight
    if metrics[:emergency_fund][:value].present?
      insights << emergency_fund_insight(metrics[:emergency_fund][:value])
    end

    # Net worth trend insight
    if metrics[:net_worth_trend][:value].present?
      insights << net_worth_trend_insight(metrics[:net_worth_trend][:value][:percentage])
    end

    insights.compact
  end

  private

    def savings_rate_insight(rate)
      if rate >= 20
        {
          icon: "check-circle",
          color: "text-success",
          title: I18n.t("financial_health.insights.savings_rate.excellent.title"),
          description: I18n.t("financial_health.insights.savings_rate.excellent.description")
        }
      elsif rate >= 10
        {
          icon: "info",
          color: "text-warning",
          title: I18n.t("financial_health.insights.savings_rate.good.title"),
          description: I18n.t("financial_health.insights.savings_rate.good.description")
        }
      else
        {
          icon: "alert-triangle",
          color: "text-destructive",
          title: I18n.t("financial_health.insights.savings_rate.low.title"),
          description: I18n.t("financial_health.insights.savings_rate.low.description")
        }
      end
    end

    def debt_to_income_insight(ratio)
      if ratio < 36
        {
          icon: "check-circle",
          color: "text-success",
          title: I18n.t("financial_health.insights.debt_to_income.healthy.title"),
          description: I18n.t("financial_health.insights.debt_to_income.healthy.description")
        }
      elsif ratio <= 43
        {
          icon: "info",
          color: "text-warning",
          title: I18n.t("financial_health.insights.debt_to_income.manageable.title"),
          description: I18n.t("financial_health.insights.debt_to_income.manageable.description")
        }
      else
        {
          icon: "alert-triangle",
          color: "text-destructive",
          title: I18n.t("financial_health.insights.debt_to_income.high.title"),
          description: I18n.t("financial_health.insights.debt_to_income.high.description")
        }
      end
    end

    def emergency_fund_insight(months)
      if months >= 6
        {
          icon: "check-circle",
          color: "text-success",
          title: I18n.t("financial_health.insights.emergency_fund.strong.title"),
          description: I18n.t("financial_health.insights.emergency_fund.strong.description")
        }
      elsif months >= 3
        {
          icon: "info",
          color: "text-warning",
          title: I18n.t("financial_health.insights.emergency_fund.solid.title"),
          description: I18n.t("financial_health.insights.emergency_fund.solid.description")
        }
      else
        {
          icon: "alert-triangle",
          color: "text-destructive",
          title: I18n.t("financial_health.insights.emergency_fund.low.title"),
          description: I18n.t("financial_health.insights.emergency_fund.low.description")
        }
      end
    end

    def net_worth_trend_insight(percentage)
      if percentage > 0
        {
          icon: "trending-up",
          color: "text-success",
          title: I18n.t("financial_health.insights.net_worth.growing.title"),
          description: I18n.t("financial_health.insights.net_worth.growing.description", percentage: percentage.abs.round(1))
        }
      elsif percentage >= -5
        {
          icon: "minus",
          color: "text-warning",
          title: I18n.t("financial_health.insights.net_worth.stable.title"),
          description: I18n.t("financial_health.insights.net_worth.stable.description")
        }
      else
        {
          icon: "trending-down",
          color: "text-destructive",
          title: I18n.t("financial_health.insights.net_worth.declining.title"),
          description: I18n.t("financial_health.insights.net_worth.declining.description", percentage: percentage.abs.round(1))
        }
      end
    end
end
