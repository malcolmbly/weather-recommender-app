class Trip < ApplicationRecord
  has_many :trip_forecasts
  has_many :forecasts, through: :trip_forecasts
  has_many :recommendations, dependent: :destroy

  enum :status, {
    pending: 0,
    processing: 1,
    ready: 2,
    failed: 3
  }

  validates :city, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true

  validate :end_date_after_start_date
  validate :reasonable_trip_duration

  private
  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, "must be on or after start date") if end_date < start_date
  end

  def reasonable_trip_duration
    return unless start_date && end_date
    duration = duration_in_days
    unless (1..14).cover?(duration)
      errors.add(:base, "Trip duration must be between 1 and 14 days (currently #{duration} days)")
    end
  end

  def duration_in_days
    return 0 unless start_date && end_date
    (end_date - start_date).to_i + 1
  end
end
