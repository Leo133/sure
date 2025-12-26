class AddCashFlowFieldsToRecurringTransactions < ActiveRecord::Migration[7.2]
  def change
    add_column :recurring_transactions, :confidence_score, :decimal, precision: 5, scale: 4, default: 0.7
    add_column :recurring_transactions, :last_matched_at, :datetime
    add_column :recurring_transactions, :paused_until, :date
  end
end
