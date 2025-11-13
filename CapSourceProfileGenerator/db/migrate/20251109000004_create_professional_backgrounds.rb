class CreateProfessionalBackgrounds < ActiveRecord::Migration[8.0]
  def change
    create_table :professional_backgrounds do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :partner, null: true, foreign_key: true

      t.string :employer
      t.string :position
      t.boolean :current_job, default: false
      t.string :start_month
      t.string :end_month
      t.string :start_year
      t.string :end_year

      # Additional fields from ProfileGenerator
      t.string :location
      t.text :description
      t.text :achievements # Could be JSON array stored as text

      t.timestamps
    end

    add_index :professional_backgrounds, :current_job
  end
end
