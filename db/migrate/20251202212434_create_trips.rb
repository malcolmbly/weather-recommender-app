class CreateTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :trips do |t|
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :city, null: false

      t.timestamps
    end
  end
end
