class CreatePartnerUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_users do |t|
      t.references :partner, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role

      t.timestamps
    end

    add_index :partner_users, [:user_id, :partner_id], unique: true
  end
end
