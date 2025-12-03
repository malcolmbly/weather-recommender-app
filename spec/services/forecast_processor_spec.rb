# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ForecastProcessor do
  let(:trip) do
    Trip.create!(
      city: 'Boston',
      start_date: Date.today,
      end_date: Date.today + 2.days
    )
  end

  let(:processor) { described_class.new(trip: trip) }

  let(:forecast_data) do
    [
      {
        city: 'Boston',
        date: Date.today,
        temperature_max: 75.5,
        temperature_min: 55.2,
        temperature_avg: 65.3,
        temperature_apparent_max: 73.0,
        temperature_apparent_min: 53.0,
        temperature_apparent_avg: 63.0,
        conditions: 'Clear, Sunny',
        precipitation_probability: 10.0,
        uv_index_max: 5
      },
      {
        city: 'Boston',
        date: Date.today + 1.day,
        temperature_max: 68.8,
        temperature_min: 48.3,
        temperature_avg: 58.5,
        temperature_apparent_max: 66.0,
        temperature_apparent_min: 46.0,
        temperature_apparent_avg: 56.0,
        conditions: 'Rain',
        precipitation_probability: 75.5,
        uv_index_max: 3
      },
      {
        city: 'Boston',
        date: Date.today + 2.days,
        temperature_max: 80.2,
        temperature_min: 60.1,
        temperature_avg: 70.1,
        temperature_apparent_max: 78.0,
        temperature_apparent_min: 58.0,
        temperature_apparent_avg: 68.0,
        conditions: 'Mostly Clear',
        precipitation_probability: 5.0,
        uv_index_max: 7
      }
    ]
  end

  describe '#initialize' do
    it 'sets the trip' do
      expect(processor.instance_variable_get(:@trip)).to eq(trip)
    end
  end

  describe '#process' do
    context 'when no forecasts exist for the trip dates' do
      before do
        # Mock the API fetcher to return forecast data
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(forecast_data)
      end

      it 'calls the API fetcher' do
        fetcher = instance_double(WeatherForecastApiFetcher)
        expect(WeatherForecastApiFetcher).to receive(:new).with(
          trip.city,
          trip.start_date,
          trip.end_date
        ).and_return(fetcher)
        expect(fetcher).to receive(:fetch).and_return(forecast_data)

        processor.process
      end

      it 'creates Forecast records' do
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(forecast_data)

        expect {
          processor.process
        }.to change(Forecast, :count).by(3)
      end

      it 'creates TripForecast join records' do
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(forecast_data)

        expect {
          processor.process
        }.to change(TripForecast, :count).by(3)
      end

      it 'links all forecasts to the trip' do
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(forecast_data)

        processor.process
        trip.reload

        expect(trip.forecasts.count).to eq(3)
        expect(trip.forecasts.pluck(:city).uniq).to eq(['Boston'])
      end

      it 'returns the forecast records' do
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(forecast_data)

        result = processor.process

        expect(result).to be_an(ActiveRecord::Relation)
        expect(result.count).to eq(3)
        expect(result.first).to be_a(Forecast)
      end
    end

    context 'when some forecasts already exist' do
      before do
        # Create one existing forecast
        Forecast.create!(
          city: 'Boston',
          date: Date.today,
          temperature_max: 70.0,
          temperature_min: 50.0,
          temperature_avg: 60.0,
          conditions: 'Sunny'
        )

        # Mock API fetcher to return data for all 3 days
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(forecast_data)
      end

      it 'reuses existing forecast' do
        expect(Forecast.where(city: 'Boston', date: Date.today).count).to eq(1)

        expect {
          processor.process
        }.to change(Forecast, :count).by(2) # Only 2 new forecasts created

        expect(Forecast.where(city: 'Boston', date: Date.today).count).to eq(1) # Still only one for today
      end

      it 'links existing forecasts to the trip' do
        processor.process
        trip.reload

        expect(trip.forecasts.count).to eq(3)
        expect(trip.forecasts.pluck(:date)).to include(Date.today)
      end
    end

    context 'when all forecasts already exist (deduplication)' do
      before do
        # Create all forecasts before processing
        forecast_data.each do |data|
          Forecast.create!(data)
        end
      end

      it 'does not make API call' do
        expect(WeatherForecastApiFetcher).not_to receive(:new)

        processor.process
      end

      it 'does not create new Forecast records' do
        expect {
          processor.process
        }.not_to change(Forecast, :count)
      end

      it 'creates TripForecast join records' do
        expect {
          processor.process
        }.to change(TripForecast, :count).by(3)
      end

      it 'links existing forecasts to trip' do
        processor.process
        trip.reload

        expect(trip.forecasts.count).to eq(3)
      end
    end

    context 'when API fetcher raises WeatherAPIError' do
      before do
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_raise(
          WeatherForecastApiFetcher::WeatherAPIError, 'API key invalid'
        )
      end

      it 'raises ProcessingError' do
        expect {
          processor.process
        }.to raise_error(
          ForecastProcessor::ProcessingError,
          /Failed to fetch weather data: API key invalid/
        )
      end

      it 'does not create any Forecast records' do
        expect {
          begin
            processor.process
          rescue ForecastProcessor::ProcessingError
            # Expected error
          end
        }.not_to change(Forecast, :count)
      end
    end

    context 'when database operation fails' do
      before do
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(forecast_data)

        # Mock a validation failure
        allow_any_instance_of(Forecast).to receive(:save!).and_raise(
          ActiveRecord::RecordInvalid
        )
      end

      it 'raises ProcessingError' do
        expect {
          processor.process
        }.to raise_error(
          ForecastProcessor::ProcessingError,
          /Failed to save forecast data/
        )
      end
    end

    context 'with multiple trips for same city and overlapping dates' do
      let(:trip2) do
        Trip.create!(
          city: 'Boston',
          start_date: Date.today,
          end_date: Date.today + 1.day
        )
      end

      before do
        # Process first trip to create forecasts
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(forecast_data)
        processor.process
      end

      it 'reuses existing forecasts for second trip' do
        processor2 = described_class.new(trip: trip2)

        expect(WeatherForecastApiFetcher).not_to receive(:new)

        expect {
          processor2.process
        }.not_to change(Forecast, :count)
      end

      it 'creates separate TripForecast records for each trip' do
        processor2 = described_class.new(trip: trip2)

        expect {
          processor2.process
        }.to change(TripForecast, :count).by(2) # Only 2 days for trip2

        trip2.reload
        expect(trip2.forecasts.count).to eq(2)
      end

      it 'does not duplicate TripForecast records' do
        processor2 = described_class.new(trip: trip2)
        processor2.process

        # Process again - should not create duplicates
        expect {
          processor2.process
        }.not_to change(TripForecast, :count)
      end
    end
  end

  describe 'edge cases' do
    context 'when trip has only one day' do
      let(:single_day_trip) do
        Trip.create!(
          city: 'Miami',
          start_date: Date.today,
          end_date: Date.today
        )
      end

      let(:single_day_processor) { described_class.new(trip: single_day_trip) }

      it 'processes single day correctly' do
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return([forecast_data.first.merge(city: 'Miami')])

        result = single_day_processor.process
        single_day_trip.reload

        expect(single_day_trip.forecasts.count).to eq(1)
      end
    end

    context 'when city has different capitalization' do
      let(:trip_caps) do
        Trip.create!(
          city: 'boston', # lowercase
          start_date: Date.today,
          end_date: Date.today + 1.day
        )
      end

      before do
        # Create forecast with uppercase city
        Forecast.create!(
          city: 'Boston',
          date: Date.today,
          temperature_max: 70.0,
          temperature_min: 50.0,
          temperature_avg: 60.0,
          conditions: 'Sunny'
        )
      end

      it 'city comparison is case-sensitive' do
        fetcher = instance_double(WeatherForecastApiFetcher)
        allow(WeatherForecastApiFetcher).to receive(:new).and_return(fetcher)
        allow(fetcher).to receive(:fetch).and_return(
          forecast_data[0..1].map { |f| f.merge(city: 'boston') }
        )

        processor_caps = described_class.new(trip: trip_caps)

        # Should create new forecasts because city case doesn't match
        expect {
          processor_caps.process
        }.to change(Forecast, :count).by(2)
      end
    end
  end
end
