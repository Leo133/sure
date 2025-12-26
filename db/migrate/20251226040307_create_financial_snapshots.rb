class CreateFinancialSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :financial_snapshots, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid

      # Snapshot date (point-in-time)
      t.date :snapshot_date, null: false

      # Core monetary values (stored in family's base currency)
      t.decimal :net_worth, precision: 19, scale: 4
      t.decimal :liquid_assets, precision: 19, scale: 4
      t.decimal :total_debt, precision: 19, scale: 4
      t.decimal :monthly_income, precision: 19, scale: 4
      t.decimal :monthly_expenses, precision: 19, scale: 4
      t.decimal :monthly_savings, precision: 19, scale: 4

      # Calculated metrics
      t.decimal :savings_rate, precision: 7, scale: 4          # Percentage (e.g., 25.5000)
      t.decimal :debt_to_income_ratio, precision: 7, scale: 4  # Percentage
      t.decimal :emergency_fund_months, precision: 5, scale: 2 # Months of coverage

      # Currency for monetary values
      t.string :currency, null: false

      # Additional calculated values (flexible storage)
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Compound index for time-series queries
    add_index :financial_snapshots, [:family_id, :snapshot_date], unique: true
    add_index :financial_snapshots, :snapshot_date
  end
end
