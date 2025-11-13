class CreateEducationalBackgrounds < ActiveRecord::Migration[8.0]
  def change
    create_table :educational_backgrounds do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :partner, null: true, foreign_key: true

      t.string :university_college
      t.integer :graduation_year
      t.string :major
      t.string :degree
      t.string :month_start
      t.string :month_end
      t.string :year_start
      t.string :year_end

      # Additional fields from ProfileGenerator
      t.decimal :gpa, precision: 3, scale: 2
      t.string :honors

      t.timestamps
    end
  end
end
