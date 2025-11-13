class CreateActionTextTables < ActiveRecord::Migration[8.0]
  def change
    # Action Text Rich Text table for all rich text fields
    create_table :action_text_rich_texts do |t|
      t.string :name, null: false
      t.text :body # SQLite doesn't support size parameter
      t.references :record, null: false, polymorphic: true, index: false

      t.timestamps
    end

    add_index :action_text_rich_texts, [:record_type, :record_id, :name],
              name: 'index_action_text_rich_texts_uniqueness', unique: true
  end
end
