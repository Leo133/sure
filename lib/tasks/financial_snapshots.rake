namespace :financial_snapshots do
  desc "Backfill historical financial snapshots for a family"
  task :backfill, [ :family_id, :months ] => :environment do |_t, args|
    family_id = args[:family_id]
    months = (args[:months] || 12).to_i

    if family_id.blank?
      puts "Usage: rake financial_snapshots:backfill[family_id,months]"
      puts "  family_id: UUID of the family (required)"
      puts "  months: Number of months to backfill (default: 12)"
      exit 1
    end

    family = Family.find_by(id: family_id)

    unless family
      puts "Family not found with ID: #{family_id}"
      exit 1
    end

    puts "Backfilling #{months} months of financial snapshots for family: #{family.name || family.id}"

    created_count = 0
    skipped_count = 0

    months.times do |i|
      date = (Date.current - (i + 1).months).end_of_month

      if family.financial_snapshots.exists?(snapshot_date: date)
        puts "  Skipping #{date.strftime('%B %Y')} - snapshot already exists"
        skipped_count += 1
        next
      end

      begin
        FinancialSnapshot.calculate_for_family!(family, date: date)
        puts "  Created snapshot for #{date.strftime('%B %Y')}"
        created_count += 1
      rescue StandardError => e
        puts "  Error creating snapshot for #{date.strftime('%B %Y')}: #{e.message}"
      end
    end

    puts "\nBackfill complete: #{created_count} created, #{skipped_count} skipped"
  end

  desc "Backfill historical financial snapshots for all families"
  task backfill_all: :environment do
    months = ENV.fetch("MONTHS", 12).to_i

    puts "Backfilling #{months} months of financial snapshots for all families..."

    Family.find_each do |family|
      puts "\nProcessing family: #{family.name || family.id}"

      # Skip families with no entries
      unless family.entries.exists?
        puts "  Skipping - no transaction data"
        next
      end

      created_count = 0
      months.times do |i|
        date = (Date.current - (i + 1).months).end_of_month

        next if family.financial_snapshots.exists?(snapshot_date: date)

        begin
          FinancialSnapshot.calculate_for_family!(family, date: date)
          created_count += 1
        rescue StandardError => e
          puts "  Error for #{date.strftime('%B %Y')}: #{e.message}"
        end
      end

      puts "  Created #{created_count} snapshots"
    end

    puts "\nBackfill complete for all families"
  end

  desc "Generate snapshot for current month (for testing)"
  task generate_current: :environment do
    family_id = ENV.fetch("FAMILY_ID", nil)

    if family_id.blank?
      puts "Usage: FAMILY_ID=uuid rake financial_snapshots:generate_current"
      exit 1
    end

    family = Family.find_by(id: family_id)

    unless family
      puts "Family not found with ID: #{family_id}"
      exit 1
    end

    date = Date.current.last_month.end_of_month
    snapshot = FinancialSnapshot.calculate_for_family!(family, date: date)

    puts "Created snapshot for #{date.strftime('%B %Y')}:"
    puts "  Net Worth: #{snapshot.net_worth_money}"
    puts "  Liquid Assets: #{snapshot.liquid_assets_money}"
    puts "  Total Debt: #{snapshot.total_debt_money}"
    puts "  Monthly Income: #{snapshot.monthly_income_money}"
    puts "  Monthly Expenses: #{snapshot.monthly_expenses_money}"
    puts "  Savings Rate: #{snapshot.savings_rate}%"
    puts "  Debt-to-Income: #{snapshot.debt_to_income_ratio}%"
    puts "  Emergency Fund: #{snapshot.emergency_fund_months} months"
  end
end
