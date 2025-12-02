class Trip < ApplicationRecord
  has_many :trip_forecasts
  has_many :forecasts, through: :trip_forecasts
  has_many :recommendations, dependent: :destroy

  validates :city, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
end
