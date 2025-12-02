class CreateForecasts < ActiveRecord::Migration[8.1]
  def change
    create_table :forecasts do |t|
      t.string :city
      t.date :date, null: false

      t.string :conditions
      t.float :temperature_apparent_avg
      t.float :temperature_apparent_max
      t.float :temperature_apparent_min
      t.integer :uv_index_max
      t.float :temperature_avg
      t.float :temperature_max
      t.float :temperature_min

      t.timestamps
    end

    add_index :forecasts, [ :city, :date ], unique: true
  end
end
