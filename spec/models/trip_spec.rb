require 'rails_helper'

RSpec.describe Trip, type: :model do
  describe 'validations' do
    describe 'end_date_after_start_date' do
      it 'is invalid when end_date is before start_date' do
        trip = build(:trip, start_date: Date.today, end_date: Date.yesterday)
        expect(trip).not_to be_valid
        expect(trip.errors[:end_date]).to include('must be on or after start date')
      end

      it 'is valid when end_date equals start_date' do
        trip = build(:trip, start_date: Date.today, end_date: Date.today)
        expect(trip).to be_valid
      end

      it 'is valid when end_date is after start_date' do
        trip = build(:trip, start_date: Date.today, end_date: Date.tomorrow)
        expect(trip).to be_valid
      end
    end

    describe 'reasonable_trip_duration' do
      # a duration less than one day is covered by the end_date_after_start_date method
      it 'is invalid when duration exceeds 14 days' do
        trip_duration = 16
        trip = build(:trip, start_date: Date.today, end_date: Date.yesterday + trip_duration.days)
        expect(trip).not_to be_valid
        expect(trip.errors[:base]).to include(
            "Trip duration must be between 1 and 14 days (currently #{trip_duration} days)"
          )
      end

      it 'is valid with 1 day duration' do
        trip = build(:trip, start_date: Date.today, end_date: Date.today)
        expect(trip).to be_valid
      end

      it 'is valid with 14 day duration' do
        trip = build(:trip, start_date: Date.today, end_date: Date.today + 13.days)
        expect(trip).to be_valid
      end
    end
  end
end
