class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      # STI type column
      t.string :type, null: false

      # Authentication (Devise would add these, but we'll keep it simple for now)
      t.string :email
      t.string :encrypted_password

      # Personal info
      t.string :first_name
      t.string :last_name
      t.string :phone_number
      t.string :location
      t.string :linkedin
      t.string :website
      t.string :role
      t.string :slug

      # Domain and settings (stored as JSON text for SQLite compatibility)
      t.text :domain # Will be serialized as JSON array
      t.string :current_domain
      t.boolean :mentor_enabled, default: true
      t.string :sso_token

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :slug, unique: true
    add_index :users, :type
  end
end
