class CreateTripForecasts < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_forecasts do |t|
      t.references :forecast, null: false, foreign_key: true
      t.references :trip, null: false, foreign_key: true

      t.timestamps
    end
  end
end
