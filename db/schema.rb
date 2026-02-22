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

ActiveRecord::Schema[8.0].define(version: 2026_02_22_032947) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "price_histories", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.decimal "price", precision: 12, scale: 2, null: false
    t.string "currency", null: false
    t.datetime "scraped_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "scraped_at"], name: "index_price_histories_on_product_id_and_scraped_at"
    t.index ["product_id"], name: "index_price_histories_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "source", null: false
    t.text "url"
    t.text "image_url"
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source", "name"], name: "index_products_on_source_and_name"
    t.index ["source", "url"], name: "index_products_on_source_and_url", unique: true
  end

  add_foreign_key "price_histories", "products"
end
