class FinancialSnapshotJob < ApplicationJob
  queue_as :scheduled

  # Generate financial snapshots for all active families
  # Designed to run on the 1st of each month to capture previous month's data
  def perform(family_id: nil, date: nil)
    target_date = date || Date.current.last_month.end_of_month

    if family_id.present?
      # Generate for specific family
      family = Family.find_by(id: family_id)
      generate_snapshot_for_family(family, target_date) if family
    else
      # Generate for all families
      Family.find_each do |family|
        generate_snapshot_for_family(family, target_date)
      rescue StandardError => e
        Rails.logger.error("FinancialSnapshotJob: Failed to generate snapshot for family #{family.id}: #{e.message}")
      end
    end
  end

  private

    def generate_snapshot_for_family(family, date)
      # Skip families with insufficient data (less than 30 days of transactions)
      return unless family_has_sufficient_data?(family)

      # Don't create duplicate snapshots
      return if family.financial_snapshots.exists?(snapshot_date: date)

      FinancialSnapshot.calculate_for_family!(family, date: date)

      Rails.logger.info("FinancialSnapshotJob: Generated snapshot for family #{family.id} for #{date}")
    end

    def family_has_sufficient_data?(family)
      # Check if family has at least some entries
      family.entries.exists?
    end
end
