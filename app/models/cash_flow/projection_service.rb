module CashFlow
  class ProjectionService
    include Monetizable

    CONFIDENCE_PENDING = 0.95
    CONFIDENCE_AUTO_RECURRING = 0.85
    CONFIDENCE_MANUAL_RECURRING = 0.70
    CONFIDENCE_NEW_RECURRING = 0.50

    # Decay factor for confidence over time (per day)
    CONFIDENCE_DECAY_PER_DAY = 0.002

    attr_reader :family, :start_date, :end_date, :account_ids

    def initialize(family, start_date: Date.current, end_date: 90.days.from_now.to_date, account_ids: nil)
      @family = family
      @start_date = start_date.to_date
      @end_date = end_date.to_date
      @account_ids = account_ids
    end

    def currency
      family.currency
    end

    # Main method to generate complete projection
    def generate_projection
      {
        projections: daily_projections,
        balance_curve: balance_curve,
        summary: summary,
        alerts: low_balance_alerts
      }
    end

    # Generate list of projected transactions
    def daily_projections
      projections = []

      # Add pending transactions
      projections.concat(pending_transaction_projections)

      # Add recurring transaction projections
      projections.concat(recurring_transaction_projections)

      # Sort by date
      projections.sort_by { |p| [ p[:date], p[:type] == :income ? 0 : 1 ] }
    end

    # Generate balance curve over time
    def balance_curve
      curve = []
      current_balance = starting_balance
      projections_by_date = daily_projections.group_by { |p| p[:date] }
      days_from_now = 0

      (start_date..end_date).each do |date|
        day_projections = projections_by_date[date] || []

        # Calculate net change for the day
        # Income increases balance (+), expenses decrease balance (-)
        day_net = day_projections.sum do |p|
          p[:type] == :income ? p[:amount].to_d : -p[:amount].to_d
        end

        current_balance += day_net

        # Calculate confidence for the day
        day_confidence = if day_projections.any?
          day_projections.sum { |p| p[:confidence] } / day_projections.size
        else
          1.0
        end

        # Apply time decay to confidence
        decayed_confidence = [ day_confidence * (1 - (days_from_now * CONFIDENCE_DECAY_PER_DAY)), 0.3 ].max

        curve << {
          date: date,
          balance: current_balance,
          confidence: decayed_confidence.round(2),
          net_change: day_net,
          projections_count: day_projections.count
        }

        days_from_now += 1
      end

      curve
    end

    # Summary of projection data
    def summary
      projections = daily_projections
      income_projections = projections.select { |p| p[:type] == :income }
      expense_projections = projections.select { |p| p[:type] == :expense }

      {
        total_projected_income: income_projections.sum { |p| p[:amount].to_d },
        total_projected_expenses: expense_projections.sum { |p| p[:amount].to_d },
        net_projected_cash_flow: income_projections.sum { |p| p[:amount].to_d } - expense_projections.sum { |p| p[:amount].to_d },
        projection_count: projections.count,
        starting_balance: starting_balance,
        ending_balance: balance_curve.last&.dig(:balance) || starting_balance,
        date_range: { start: start_date, end: end_date }
      }
    end

    # Detect low balance alerts
    def low_balance_alerts
      alerts = []
      curve = balance_curve
      threshold = low_balance_threshold

      # Find first date where balance goes below threshold
      low_balance_dates = curve.select { |point| point[:balance] < threshold }

      if low_balance_dates.any?
        first_low = low_balance_dates.first
        alerts << {
          type: :low_balance,
          date: first_low[:date],
          projected_balance: first_low[:balance],
          threshold: threshold,
          days_until: (first_low[:date] - Date.current).to_i,
          severity: first_low[:balance] < 0 ? :critical : :warning
        }
      end

      # Find zero crossings
      zero_crossings = curve.select { |point| point[:balance] < 0 }
      if zero_crossings.any?
        first_zero = zero_crossings.first
        unless alerts.any? { |a| a[:date] == first_zero[:date] }
          alerts << {
            type: :overdraft,
            date: first_zero[:date],
            projected_balance: first_zero[:balance],
            days_until: (first_zero[:date] - Date.current).to_i,
            severity: :critical
          }
        end
      end

      alerts.sort_by { |a| a[:date] }
    end

    # Get projections for a specific date
    def projections_for_date(date)
      daily_projections.select { |p| p[:date] == date.to_date }
    end

    # What-if scenario: add a hypothetical transaction
    def scenario_with_transaction(amount:, date:, type: :expense, description: "Hypothetical transaction")
      # Clone the service and add the hypothetical
      scenario_projections = daily_projections.dup
      scenario_projections << {
        date: date.to_date,
        type: type.to_sym,
        amount: amount.to_d.abs,
        description: description,
        confidence: 1.0,
        source: :scenario,
        source_id: nil
      }

      # Recalculate balance curve with the scenario
      recalculate_balance_curve(scenario_projections.sort_by { |p| p[:date] })
    end

    # What-if scenario: remove a recurring transaction
    def scenario_without_recurring(recurring_transaction_id)
      filtered = daily_projections.reject do |p|
        p[:source] == :recurring && p[:source_id] == recurring_transaction_id
      end

      recalculate_balance_curve(filtered)
    end

    private

      def pending_transaction_projections
        pending_entries.map do |entry|
          {
            date: entry.date,
            type: entry.classification == "income" ? :income : :expense,
            amount: entry.amount.abs,
            description: entry.name,
            confidence: CONFIDENCE_PENDING,
            source: :pending,
            source_id: entry.id
          }
        end
      end

      def recurring_transaction_projections
        projections = []

        active_recurring_transactions.each do |recurring|
          # Skip paused recurring transactions (use the model's paused? method)
          next if recurring.paused?

          # Generate projections for each expected occurrence within the date range
          occurrence_dates(recurring).each do |date|
            confidence = calculate_confidence(recurring, date)

            # Use average amount for manual recurring with variance
            amount = if recurring.manual? && recurring.expected_amount_avg.present?
              recurring.expected_amount_avg
            else
              recurring.amount
            end

            projections << {
              date: date,
              type: amount.to_d < 0 ? :income : :expense,
              amount: amount.to_d.abs,
              description: recurring.merchant&.name || recurring.name,
              confidence: confidence,
              source: :recurring,
              source_id: recurring.id,
              recurring_transaction: recurring,
              amount_min: recurring.expected_amount_min,
              amount_max: recurring.expected_amount_max
            }
          end
        end

        projections
      end

      def occurrence_dates(recurring)
        dates = []
        current_date = recurring.next_expected_date || calculate_first_occurrence(recurring)

        return dates if current_date.nil?

        while current_date <= end_date
          dates << current_date if current_date >= start_date
          current_date = next_monthly_date(current_date, recurring.expected_day_of_month)
        end

        dates
      end

      def calculate_first_occurrence(recurring)
        expected_day = recurring.expected_day_of_month

        # Try this month first
        begin
          this_month = Date.new(start_date.year, start_date.month, expected_day)
          return this_month if this_month >= start_date
        rescue ArgumentError
          # Day doesn't exist in this month
        end

        # Otherwise try next month
        next_monthly_date(start_date.beginning_of_month, expected_day)
      end

      def next_monthly_date(from_date, day_of_month)
        next_month = from_date.next_month
        begin
          Date.new(next_month.year, next_month.month, day_of_month)
        rescue ArgumentError
          next_month.end_of_month
        end
      end

      def calculate_confidence(recurring, date)
        base_confidence = if recurring.manual?
          CONFIDENCE_MANUAL_RECURRING
        elsif recurring.occurrence_count >= 3
          CONFIDENCE_AUTO_RECURRING
        else
          CONFIDENCE_NEW_RECURRING
        end

        # Use stored confidence score if available
        base_confidence = recurring.confidence_score if recurring.respond_to?(:confidence_score) && recurring.confidence_score.present?

        # Apply time decay
        days_out = (date - Date.current).to_i
        decayed = base_confidence * (1 - (days_out * CONFIDENCE_DECAY_PER_DAY))

        [ decayed, 0.3 ].max.round(2)
      end

      def pending_entries
        scope = family.entries
          .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
          .where(date: start_date..end_date)

        if account_ids.present?
          scope = scope.where(account_id: account_ids)
        end

        # Filter to pending transactions by checking the extra field
        scope.select do |entry|
          entry.entryable.respond_to?(:pending?) && entry.entryable.pending?
        end
      end

      def active_recurring_transactions
        family.recurring_transactions.active.includes(:merchant)
      end

      def starting_balance
        @starting_balance ||= begin
          accounts_scope = family.accounts.active.where(classification: "asset")
          accounts_scope = accounts_scope.where(id: account_ids) if account_ids.present?

          # Assets minus liabilities
          assets = accounts_scope.sum(:balance).to_d

          liabilities_scope = family.accounts.active.where(classification: "liability")
          liabilities_scope = liabilities_scope.where(id: account_ids) if account_ids.present?
          liabilities = liabilities_scope.sum(:balance).to_d.abs

          assets - liabilities
        end
      end

      def low_balance_threshold
        # Default threshold - could be made configurable per account
        500.0
      end

      def recalculate_balance_curve(projections)
        curve = []
        current_balance = starting_balance
        projections_by_date = projections.group_by { |p| p[:date] }
        days_from_now = 0

        (start_date..end_date).each do |date|
          day_projections = projections_by_date[date] || []

          # Income increases balance (+), expenses decrease balance (-)
          day_net = day_projections.sum do |p|
            p[:type] == :income ? p[:amount].to_d : -p[:amount].to_d
          end

          current_balance += day_net

          curve << {
            date: date,
            balance: current_balance,
            net_change: day_net,
            projections_count: day_projections.count
          }

          days_from_now += 1
        end

        curve
      end
  end
end
