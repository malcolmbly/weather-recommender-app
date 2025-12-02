class Forecast < ApplicationRecord
  has_many :trip_forecasts
  has_many :trips, through: :trip_forecasts


  validates :city, presence: true
  validates :forecast_date, presence: true
end
