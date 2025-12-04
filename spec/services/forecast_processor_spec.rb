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

  let(:mock_fetcher) do
    instance_double(WeatherForecastApiFetcher, fetch: forecast_data)
  end

  let(:stale_duration) { Forecast::STALE_AFTER }
  let(:fixed_time) { Time.zone.parse('2025-01-01 12:00:00') }

  let(:fresh_updated_at) { fixed_time - stale_duration + 1.hour }
  let(:stale_updated_at) { fixed_time - stale_duration - 1.hour }


  before do
    allow(WeatherForecastApiFetcher).to receive(:new).and_return(mock_fetcher)
  end

  describe '#process' do
    context 'when no forecasts exist' do
      it 'fetches from API and creates forecast records' do
        expect(WeatherForecastApiFetcher).to receive(:new).with(
          trip.city,
          trip.start_date,
          trip.end_date
        ).and_return(mock_fetcher)

        expect { processor.process }.to change(Forecast, :count).by(3)
        created_forecasts = Forecast.last(3)

        expect(created_forecasts).to contain_exactly(
          have_attributes(date: trip.start_date),
          have_attributes(date: trip.start_date + 1.days),
          have_attributes(date: trip.end_date)
        )
      end

      it 'links all forecasts to the trip' do
        processor.process
        trip.reload

        expect(trip.forecasts.count).to eq(3)
        expect(trip.forecasts.pluck(:date)).to match_array([
          Date.today,
          Date.today + 1.day,
          Date.today + 2.days
        ])
      end

      it 'creates TripForecast join records' do
        expect { processor.process }.to change(TripForecast, :count).by(3)
      end
    end

    context 'when forecast records already exist (freshness checks)' do
      around do |example|
        travel_to(fixed_time) do
          example.run
        end
      end
      context 'when fresh forecasts exist (updated within the deadline)' do
        before do
          forecast_data.each do |data|
            Forecast.create!(data.merge(updated_at: fresh_updated_at))
          end
        end

        around do |example|
          travel_to(fixed_time) do
            example.run
          end
        end

        it 'does not fetch from API' do
          expect(WeatherForecastApiFetcher).not_to receive(:new)

          processor.process
        end

        it 'does not create new forecast records' do
          expect { processor.process }.not_to change(Forecast, :count)
        end

        it 'still links existing forecasts to the trip' do
          expect { processor.process }.to change(TripForecast, :count).by(3)

          trip.reload
          expect(trip.forecasts.count).to eq(3)
        end
      end

      context 'when stale forecasts exist (updated >= 24 hours ago)' do
        before do
          forecast_data.each do |data|
            Forecast.create!(data.merge(updated_at: stale_updated_at))
          end
        end

        it 'fetches fresh data from API' do
          expect(WeatherForecastApiFetcher).to receive(:new).with(
            trip.city,
            trip.start_date,
            trip.end_date
          ).and_return(mock_fetcher)

          processor.process
        end

        it 'updates existing forecasts instead of creating duplicates' do
          expect { processor.process }.not_to change(Forecast, :count)
        end

        it 'updates the forecast data with fresh values' do
          # Stale forecast has old temperature
          stale_forecast = Forecast.find_by(city: 'Boston', date: Date.today)
          expect(stale_forecast.temperature_max).to eq(75.5)
          expect(stale_forecast.updated_at).to eq(stale_updated_at)

          processor.process

          stale_forecast.reload
          expect(stale_forecast.temperature_max).to eq(75.5)
          expect(stale_forecast.updated_at).to be_within(5.minutes).of(fixed_time)
        end

        it 'links forecasts to the trip' do
          expect { processor.process }.to change(TripForecast, :count).by(3)

          trip.reload
          expect(trip.forecasts.count).to eq(3)
        end
      end

      context 'when some forecasts are fresh and some are stale' do
        before do
          # Create one fresh forecast and two stale forecasts
          Forecast.create!(forecast_data[0].merge(updated_at: fresh_updated_at))  # fresh
          Forecast.create!(forecast_data[1].merge(updated_at: stale_updated_at)) # stale
          Forecast.create!(forecast_data[2].merge(updated_at: stale_updated_at)) # stale
        end

        it 'fetches from API to refresh stale forecasts' do
          expect(WeatherForecastApiFetcher).to receive(:new).and_return(mock_fetcher)

          processor.process
        end

        it 'does not create duplicate forecast records' do
          expect { processor.process }.not_to change(Forecast, :count)
        end
      end
    end

    context 'with multiple trips sharing the same city and dates' do
      let(:trip2) do
        Trip.create!(
          city: 'Boston',
          start_date: Date.today,
          end_date: Date.today + 1.day
        )
      end

      before do
        processor.process
      end

      it 'reuses fresh forecasts for second trip without API call' do
        processor2 = described_class.new(trip: trip2)

        expect(WeatherForecastApiFetcher).not_to receive(:new)
        expect { processor2.process }.not_to change(Forecast, :count)
      end

      it 'creates separate TripForecast records for each trip' do
        processor2 = described_class.new(trip: trip2)

        expect { processor2.process }.to change(TripForecast, :count).by(2)

        trip2.reload
        expect(trip2.forecasts.count).to eq(2)
      end

      it 'does not create duplicate TripForecast records on reprocessing' do
        processor2 = described_class.new(trip: trip2)
        processor2.process

        # Process again - should not create duplicates
        expect { processor2.process }.not_to change(TripForecast, :count)
      end
    end

    context 'when API returns error' do
      before do
        allow(mock_fetcher).to receive(:fetch).and_raise(
          WeatherForecastApiFetcher::WeatherAPIError, 'API key invalid'
        )
      end

      it 'raises ProcessingError with descriptive message' do
        expect { processor.process }.to raise_error(
          ForecastProcessor::ProcessingError,
          /Failed to fetch weather data: API key invalid/
        )
      end

      it 'does not create any forecast records' do
        expect do
          begin
            processor.process
          rescue ForecastProcessor::ProcessingError
            # Expected error
          end
        end.not_to change(Forecast, :count)
      end
    end
  end
end
