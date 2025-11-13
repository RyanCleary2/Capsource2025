# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_09_000012) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "company_details", force: :cascade do |t|
    t.integer "partner_id", null: false
    t.string "headquarter"
    t.integer "growth_stage"
    t.integer "employee_size"
    t.integer "global_status"
    t.integer "experiential_learning_experience"
    t.integer "remote_collaboration_preferences"
    t.integer "student_seniority_preferences"
    t.integer "sponsor"
    t.text "administrators"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["partner_id"], name: "index_company_details_on_partner_id"
  end

  create_table "departments", force: :cascade do |t|
    t.integer "partner_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["partner_id", "name"], name: "index_departments_on_partner_id_and_name", unique: true
    t.index ["partner_id"], name: "index_departments_on_partner_id"
  end

  create_table "educational_backgrounds", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.integer "partner_id"
    t.string "university_college"
    t.integer "graduation_year"
    t.string "major"
    t.string "degree"
    t.string "month_start"
    t.string "month_end"
    t.string "year_start"
    t.string "year_end"
    t.decimal "gpa", precision: 3, scale: 2
    t.string "honors"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["partner_id"], name: "index_educational_backgrounds_on_partner_id"
    t.index ["profile_id"], name: "index_educational_backgrounds_on_profile_id"
  end

  create_table "partner_users", force: :cascade do |t|
    t.integer "partner_id", null: false
    t.integer "user_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["partner_id"], name: "index_partner_users_on_partner_id"
    t.index ["user_id", "partner_id"], name: "index_partner_users_on_user_id_and_partner_id", unique: true
    t.index ["user_id"], name: "index_partner_users_on_user_id"
  end

  create_table "partners", force: :cascade do |t|
    t.string "name", null: false
    t.string "website"
    t.string "address"
    t.string "domain"
    t.integer "year_founded"
    t.string "country", default: "US"
    t.string "slug"
    t.integer "category", default: 0
    t.integer "organization_type"
    t.integer "employees_count"
    t.integer "industry_id"
    t.integer "students_count"
    t.string "facebook"
    t.string "linkedin"
    t.string "twitter"
    t.string "youtube"
    t.string "instagram"
    t.string "video_url"
    t.string "primary_color"
    t.string "menu_color"
    t.string "anchor_color"
    t.text "business_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_partners_on_category"
    t.index ["domain"], name: "index_partners_on_domain"
    t.index ["slug"], name: "index_partners_on_slug", unique: true
  end

  create_table "professional_backgrounds", force: :cascade do |t|
    t.integer "profile_id", null: false
    t.integer "partner_id"
    t.string "employer"
    t.string "position"
    t.boolean "current_job", default: false
    t.string "start_month"
    t.string "end_month"
    t.string "start_year"
    t.string "end_year"
    t.string "location"
    t.text "description"
    t.text "achievements"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["current_job"], name: "index_professional_backgrounds_on_current_job"
    t.index ["partner_id"], name: "index_professional_backgrounds_on_partner_id"
    t.index ["profile_id"], name: "index_professional_backgrounds_on_profile_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "time_zone", default: "EST5EDT (UTC-04:00)"
    t.integer "max_mentees"
    t.string "calender_link"
    t.string "slug"
    t.integer "status", default: 0
    t.integer "category"
    t.integer "builder_step", default: 0
    t.integer "mentorship_steps", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_profiles_on_slug", unique: true
    t.index ["status"], name: "index_profiles_on_status"
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "tag_resources", force: :cascade do |t|
    t.integer "tag_id", null: false
    t.string "resource_type", null: false
    t.integer "resource_id", null: false
    t.integer "proficiency_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resource_type", "resource_id", "tag_id"], name: "index_tag_resources_on_resource_and_tag", unique: true
    t.index ["resource_type", "resource_id"], name: "index_tag_resources_on_resource"
    t.index ["tag_id"], name: "index_tag_resources_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.integer "category", null: false
    t.string "parent_category"
    t.integer "parent_id"
    t.integer "domain_id"
    t.integer "partner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_tags_on_category"
    t.index ["domain_id"], name: "index_tags_on_domain_id"
    t.index ["name", "category"], name: "index_tags_on_name_and_category"
    t.index ["parent_id"], name: "index_tags_on_parent_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "type", null: false
    t.string "email"
    t.string "encrypted_password"
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.string "location"
    t.string "linkedin"
    t.string "website"
    t.string "role"
    t.string "slug"
    t.text "domain"
    t.string "current_domain"
    t.boolean "mentor_enabled", default: true
    t.string "sso_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["type"], name: "index_users_on_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "company_details", "partners"
  add_foreign_key "departments", "partners"
  add_foreign_key "educational_backgrounds", "partners"
  add_foreign_key "educational_backgrounds", "profiles"
  add_foreign_key "partner_users", "partners"
  add_foreign_key "partner_users", "users"
  add_foreign_key "professional_backgrounds", "partners"
  add_foreign_key "professional_backgrounds", "profiles"
  add_foreign_key "profiles", "users"
  add_foreign_key "tag_resources", "tags"
end
