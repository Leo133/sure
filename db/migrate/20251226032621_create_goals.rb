class CreateGoals < ActiveRecord::Migration[7.2]
  def change
    create_table :goals, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid

      # Core fields
      t.string :name, null: false
      t.string :goal_type, null: false, default: "savings"
      t.decimal :target_amount, precision: 19, scale: 4, null: false
      t.string :currency, null: false
      t.date :target_date
      t.string :status, null: false, default: "active"

      # Progress tracking
      t.decimal :current_amount, precision: 19, scale: 4, default: 0
      t.date :start_date
      t.datetime :completed_at

      # Customization
      t.string :color
      t.string :lucide_icon
      t.text :description

      # Special: linked account IDs for automatic progress tracking
      t.jsonb :linked_account_ids, default: []

      # Milestones: percentage checkpoints with reached dates
      t.jsonb :milestones, default: []

      t.timestamps
    end

    add_index :goals, [:family_id, :status]
    add_index :goals, :target_date
  end
end
