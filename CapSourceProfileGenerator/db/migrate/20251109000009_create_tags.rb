class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.integer :category, null: false
      t.string :parent_category
      t.integer :parent_id
      t.integer :domain_id
      t.integer :partner_id

      t.timestamps
    end

    add_index :tags, [:name, :category]
    add_index :tags, :category
    add_index :tags, :parent_id
    add_index :tags, :domain_id
  end
end
