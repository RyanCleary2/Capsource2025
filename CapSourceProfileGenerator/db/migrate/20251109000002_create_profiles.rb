class CreateProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true

      # Profile settings
      t.string :time_zone, default: "EST5EDT (UTC-04:00)"
      t.integer :max_mentees
      t.string :calender_link
      t.string :slug

      # Enums (stored as integers)
      t.integer :status, default: 0
      t.integer :category
      t.integer :builder_step, default: 0
      t.integer :mentorship_steps, default: 0

      t.timestamps
    end

    add_index :profiles, :slug, unique: true
    add_index :profiles, :status
  end
end
