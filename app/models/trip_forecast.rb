class TripForecast < ApplicationRecord
  belongs_to :trip
  belongs_to :forecast

  validates :forecast_id, uniqueness: { scope: :trip_id, message: "already linked to this trip" }
end
