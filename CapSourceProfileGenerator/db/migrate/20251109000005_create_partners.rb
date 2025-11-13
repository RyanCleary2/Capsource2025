class CreatePartners < ActiveRecord::Migration[8.0]
  def change
    create_table :partners do |t|
      t.string :name, null: false
      t.string :website
      t.string :address
      t.string :domain # subdomain for white-labeling
      t.integer :year_founded
      t.string :country, default: "US"
      t.string :slug

      # Enums
      t.integer :category, default: 0 # company=0, school=1
      t.integer :organization_type
      t.integer :employees_count

      # Industry reference
      t.integer :industry_id

      # For schools
      t.integer :students_count

      # Social media
      t.string :facebook
      t.string :linkedin
      t.string :twitter
      t.string :youtube
      t.string :instagram
      t.string :video_url

      # Branding colors
      t.string :primary_color
      t.string :menu_color
      t.string :anchor_color

      # Additional field from ProfileGenerator
      t.text :business_model

      t.timestamps
    end

    add_index :partners, :slug, unique: true
    add_index :partners, :category
    add_index :partners, :domain
  end
end
