class CreateSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :skills do |t|
      t.string :name
      t.text :description
      t.references :category, null: false, foreign_key: true
      t.references :parent_skill, null: false, foreign_key: true
      t.string :skill_level
      t.json :aliases
      t.json :tags
      t.string :domain
      t.string :partner

      t.timestamps
    end
  end
end
