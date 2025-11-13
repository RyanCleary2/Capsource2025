class CreateCompanyDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :company_details do |t|
      t.references :partner, null: false, foreign_key: true

      t.string :headquarter

      # Enums
      t.integer :growth_stage
      t.integer :employee_size
      t.integer :global_status
      t.integer :experiential_learning_experience
      t.integer :remote_collaboration_preferences
      t.integer :student_seniority_preferences
      t.integer :sponsor

      # Additional field for schools
      t.text :administrators

      t.timestamps
    end
  end
end
