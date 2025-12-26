class CreateGoalContributions < ActiveRecord::Migration[7.2]
  def change
    create_table :goal_contributions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :goal, null: false, foreign_key: true, type: :uuid
      t.references :transaction, foreign_key: { to_table: :transactions }, type: :uuid

      t.decimal :amount, precision: 19, scale: 4, null: false
      t.string :currency, null: false
      t.date :contribution_date, null: false
      t.string :contribution_type, null: false, default: "manual"
      t.text :notes

      t.timestamps
    end

    add_index :goal_contributions, [:goal_id, :contribution_date]
  end
end
