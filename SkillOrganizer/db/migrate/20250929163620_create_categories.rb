class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name
      t.text :description
      t.references :parent_category, null: false, foreign_key: true

      t.timestamps
    end
  end
end
