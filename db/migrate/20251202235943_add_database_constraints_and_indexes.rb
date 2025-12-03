class AddDatabaseConstraintsAndIndexes < ActiveRecord::Migration[8.1]
  def change
    # Add NOT NULL constraint to forecasts.city
    change_column_null :forecasts, :city, false

    # Add NOT NULL constraints to recommendations
    change_column_null :recommendations, :clothing_category, false
    change_column_null :recommendations, :details, false

    # Add unique composite index on trip_forecasts to prevent duplicate joins
    add_index :trip_forecasts, [:trip_id, :forecast_id], unique: true
  end
end
