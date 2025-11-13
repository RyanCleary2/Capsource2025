class CreateDepartments < ActiveRecord::Migration[8.0]
  def change
    create_table :departments do |t|
      t.references :partner, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :departments, [:partner_id, :name], unique: true
  end
end
