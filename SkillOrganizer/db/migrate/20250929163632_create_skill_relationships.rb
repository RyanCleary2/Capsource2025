class CreateSkillRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :skill_relationships do |t|
      t.references :skill, null: false, foreign_key: true
      t.references :related_skill, null: false, foreign_key: true
      t.string :relationship_type

      t.timestamps
    end
  end
end
