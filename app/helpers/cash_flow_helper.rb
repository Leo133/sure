module CashFlowHelper
  def calendar_dates(start_date, end_date)
    # Get the first day of the calendar grid (Sunday of the week containing start_date)
    calendar_start = start_date.beginning_of_month.beginning_of_week(:sunday)
    # Get the last day of the calendar grid (Saturday of the week containing end_date)
    calendar_end = end_date.end_of_month.end_of_week(:sunday)

    (calendar_start..calendar_end).to_a
  end

  def projection_confidence_color(confidence)
    if confidence >= 0.8
      "text-success"
    elsif confidence >= 0.5
      "text-warning"
    else
      "text-subdued"
    end
  end

  def projection_confidence_label(confidence)
    percentage = (confidence * 100).round

    if percentage >= 80
      I18n.t("cash_flow.confidence.high", percentage: percentage)
    elsif percentage >= 50
      I18n.t("cash_flow.confidence.medium", percentage: percentage)
    else
      I18n.t("cash_flow.confidence.low", percentage: percentage)
    end
  end

  def projection_type_icon(type)
    case type
    when :income
      "arrow-down-left"
    when :expense
      "arrow-up-right"
    else
      "repeat"
    end
  end

  def projection_type_color(type)
    case type
    when :income
      "text-success"
    when :expense
      "text-destructive"
    else
      "text-subdued"
    end
  end

  def cash_flow_day_status(balance, previous_balance = nil)
    if balance < 0
      :negative
    elsif balance < 500 # Low balance threshold
      :warning
    elsif previous_balance && balance > previous_balance
      :positive
    else
      :neutral
    end
  end

  def cash_flow_day_status_class(status)
    case status
    when :negative
      "bg-destructive/10 border-destructive/20"
    when :warning
      "bg-warning/10 border-warning/20"
    when :positive
      "bg-success/10 border-success/20"
    else
      "bg-container"
    end
  end

  def format_projection_amount(projection)
    amount = projection[:amount]
    prefix = projection[:type] == :income ? "+" : "-"

    "#{prefix}#{number_to_currency(amount)}"
  end

  def alert_severity_class(severity)
    case severity
    when :critical
      "bg-destructive/10 border-destructive/20 text-destructive"
    when :warning
      "bg-warning/10 border-warning/20 text-warning"
    else
      "bg-surface-inset text-subdued"
    end
  end

  def alert_icon(alert)
    case alert[:type]
    when :overdraft
      "alert-octagon"
    when :low_balance
      "alert-triangle"
    else
      "alert-circle"
    end
  end
end
