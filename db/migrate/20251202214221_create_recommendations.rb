class CreateRecommendations < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendations do |t|
      t.references :trip, null: false, foreign_key: true
      t.string :clothing_category
      t.text :details

      t.timestamps
    end
  end
end
