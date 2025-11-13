class CreateTagResources < ActiveRecord::Migration[8.0]
  def change
    create_table :tag_resources do |t|
      t.references :tag, null: false, foreign_key: true
      t.references :resource, polymorphic: true, null: false
      t.integer :proficiency_level # Optional: for skill proficiency levels

      t.timestamps
    end

    add_index :tag_resources, [:resource_type, :resource_id, :tag_id], unique: true, name: 'index_tag_resources_on_resource_and_tag'
  end
end
