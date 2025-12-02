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

ActiveRecord::Schema[8.1].define(version: 2025_12_02_221154) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "forecasts", force: :cascade do |t|
    t.string "city"
    t.string "conditions"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.float "temperature_apparent_avg"
    t.float "temperature_apparent_max"
    t.float "temperature_apparent_min"
    t.float "temperature_avg"
    t.float "temperature_max"
    t.float "temperature_min"
    t.datetime "updated_at", null: false
    t.integer "uv_index_max"
    t.index ["city", "date"], name: "index_forecasts_on_city_and_date", unique: true
  end

  create_table "recommendations", force: :cascade do |t|
    t.string "clothing_category"
    t.datetime "created_at", null: false
    t.text "details"
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id"], name: "index_recommendations_on_trip_id"
  end

  create_table "trip_forecasts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "forecast_id", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["forecast_id"], name: "index_trip_forecasts_on_forecast_id"
    t.index ["trip_id"], name: "index_trip_forecasts_on_trip_id"
  end

  create_table "trips", force: :cascade do |t|
    t.string "city", null: false
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "recommendations", "trips"
  add_foreign_key "trip_forecasts", "forecasts"
  add_foreign_key "trip_forecasts", "trips"
end
