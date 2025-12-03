class Forecast < ApplicationRecord
  has_many :trip_forecasts
  has_many :trips, through: :trip_forecasts

  validates :city, presence: true
  validates :date, presence: true
  validates :city, uniqueness: { scope: :date }
end
