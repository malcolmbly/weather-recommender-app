class TripForecast < ApplicationRecord
  belongs_to :trip
  belongs_to :forecast
end
