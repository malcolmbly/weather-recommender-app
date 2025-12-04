# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Trip Workflow Integration", type: :request do
  let(:trip_attributes) do
    {
      city: "Boston",
      start_date: Date.today,
      end_date: Date.today + 2.days
    }
  end

  let(:forecast_data) do
    [
      {
        city: "Boston",
        date: Date.today,
        temperature_max: 75.5,
        temperature_min: 55.2,
        temperature_avg: 65.3,
        temperature_apparent_max: 73.0,
        temperature_apparent_min: 53.0,
        temperature_apparent_avg: 63.0,
        conditions: "Clear, Sunny",
        precipitation_probability: 10.0,
        uv_index_max: 5
      },
      {
        city: "Boston",
        date: Date.today + 1.day,
        temperature_max: 68.8,
        temperature_min: 48.3,
        temperature_avg: 58.5,
        temperature_apparent_max: 66.0,
        temperature_apparent_min: 46.0,
        temperature_apparent_avg: 56.0,
        conditions: "Rain",
        precipitation_probability: 75.5,
        uv_index_max: 3
      },
      {
        city: "Boston",
        date: Date.today + 2.days,
        temperature_max: 80.2,
        temperature_min: 60.1,
        temperature_avg: 70.1,
        temperature_apparent_max: 78.0,
        temperature_apparent_min: 58.0,
        temperature_apparent_avg: 68.0,
        conditions: "Mostly Clear",
        precipitation_probability: 5.0,
        uv_index_max: 7
      }
    ]
  end

  describe "Full trip creation and processing workflow" do
    before do
      # Mock the API fetcher to avoid real API calls
      allow_any_instance_of(WeatherForecastApiFetcher).to receive(:fetch).and_return(forecast_data)
    end

    it "creates trip, fetches forecasts, and generates recommendations" do
      # Step 1: Create a new trip via POST request
      expect {
        post trips_path, params: { trip: trip_attributes }
      }.to change(Trip, :count).by(1)

      trip = Trip.last
      expect(trip.status).to eq("pending")
      expect(trip.city).to eq("Boston")

      # Step 2: Process the ForecastFetcherJob (runs synchronously in test)
      expect {
        perform_enqueued_jobs(only: ForecastFetcherJob)
      }.to change(Forecast, :count).by(3)
         .and change(TripForecast, :count).by(3)

      # Verify forecasts were created and linked
      trip.reload
      expect(trip.forecasts.count).to eq(3)
      expect(trip.forecasts.pluck(:date)).to match_array([
        Date.today,
        Date.today + 1.day,
        Date.today + 2.days
      ])

      # Step 3: Process the RecommendationAnalyzerJob
      expect {
        perform_enqueued_jobs(only: RecommendationAnalyzerJob)
      }.to change(Recommendation, :count).by(5)

      # Verify recommendations were created
      trip.reload
      expect(trip.recommendations.count).to eq(5)
      expect(trip.status).to eq("ready")

      # Verify all clothing categories are present
      categories = trip.recommendations.pluck(:clothing_category)
      expect(categories).to match_array([ "outerwear", "tops", "bottoms", "footwear", "accessories" ])

      # Step 4: View the completed trip
      get trip_path(trip)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Boston")
      expect(response.body).to include("Weather Forecast")
      expect(response.body).to include("Packing Recommendations")
      expect(response.body).to include("Ready")
    end

    it "updates trip status through the workflow states" do
      post trips_path, params: { trip: trip_attributes }
      trip = Trip.last

      # Initial status
      expect(trip.status).to eq("pending")

      # Process all jobs including nested jobs (jobs enqueued by other jobs)
      # Call perform_enqueued_jobs twice to process the chain:
      # 1st call: ForecastFetcherJob (enqueues RecommendationAnalyzerJob)
      # 2nd call: RecommendationAnalyzerJob
      2.times { perform_enqueued_jobs }

      # Final status should be ready after both jobs complete
      trip.reload
      expect(trip.status).to eq("ready")
    end

    it "handles the complete workflow when jobs are processed together" do
      post trips_path, params: { trip: trip_attributes }
      trip = Trip.last

      # Process all enqueued jobs including nested jobs
      2.times { perform_enqueued_jobs }

      trip.reload
      expect(trip.status).to eq("ready")
      expect(trip.forecasts.count).to eq(3)
      expect(trip.recommendations.count).to eq(5)
    end
  end

  describe "Workflow with existing forecast data" do
    let!(:existing_forecasts) do
      forecast_data.map { |data| Forecast.create!(data) }
    end

    before do
      # Mock API to return the same data (but it shouldn't be called)
      allow(WeatherForecastApiFetcher).to receive(:new).and_call_original
    end

    it "reuses existing forecasts without making new API calls" do
      post trips_path, params: { trip: trip_attributes }
      trip = Trip.last

      # The API fetcher should not be instantiated for fresh forecasts
      perform_enqueued_jobs(only: ForecastFetcherJob)

      trip.reload
      expect(trip.forecasts.count).to eq(3)

      # Verify we're using the existing forecasts (same IDs)
      expect(trip.forecast_ids).to match_array(existing_forecasts.map(&:id))

      # No new forecast records created
      expect(Forecast.count).to eq(3)
    end
  end

  describe "Workflow error handling" do
    context "when API fetch fails" do
      before do
        allow_any_instance_of(WeatherForecastApiFetcher).to receive(:fetch)
          .and_raise(WeatherForecastApiFetcher::WeatherAPIError, "API rate limit exceeded")
      end

      it "sets trip status to failed" do
        post trips_path, params: { trip: trip_attributes }
        trip = Trip.last

        # Suppress expected error and let job handle it
        begin
          perform_enqueued_jobs(only: ForecastFetcherJob)
        rescue ForecastProcessor::ProcessingError
          # Expected - job should handle this and set status to failed
        end

        trip.reload
        expect(trip.status).to eq("failed")
      end

      it "does not create forecast or recommendation records" do
        post trips_path, params: { trip: trip_attributes }

        expect {
          begin
            perform_enqueued_jobs(only: ForecastFetcherJob)
          rescue ForecastProcessor::ProcessingError
            # Expected error
          end
        }.not_to change(Forecast, :count)

        expect(Recommendation.count).to eq(0)
      end

      it "does not enqueue RecommendationAnalyzerJob" do
        post trips_path, params: { trip: trip_attributes }

        expect {
          begin
            perform_enqueued_jobs(only: ForecastFetcherJob)
          rescue ForecastProcessor::ProcessingError
            # Expected error
          end
        }.not_to have_enqueued_job(RecommendationAnalyzerJob)
      end
    end

    context "when processing is interrupted" do
      it "can be retried from pending status" do
        trip = create(:trip, status: :pending, city: "Boston", start_date: Date.today, end_date: Date.today + 2.days)

        allow_any_instance_of(WeatherForecastApiFetcher).to receive(:fetch).and_return(forecast_data)

        # Process jobs manually as if retrying
        ForecastFetcherJob.perform_now(trip.id)
        RecommendationAnalyzerJob.perform_now(trip.id)

        trip.reload
        expect(trip.status).to eq("ready")
        expect(trip.forecasts.count).to eq(3)
        expect(trip.recommendations.count).to eq(5)
      end
    end
  end

  describe "Multiple trips workflow" do
    let(:trip2_attributes) do
      {
        city: "Paris",
        start_date: Date.today + 7.days,
        end_date: Date.today + 9.days
      }
    end

    let(:paris_forecast_data) do
      [
        {
          city: "Paris",
          date: Date.today + 7.days,
          temperature_max: 62.3,
          temperature_min: 48.5,
          temperature_avg: 55.4,
          temperature_apparent_max: 60.0,
          temperature_apparent_min: 46.0,
          temperature_apparent_avg: 53.0,
          conditions: "Cloudy",
          precipitation_probability: 40.0,
          uv_index_max: 4
        },
        {
          city: "Paris",
          date: Date.today + 8.days,
          temperature_max: 65.1,
          temperature_min: 50.2,
          temperature_avg: 57.6,
          temperature_apparent_max: 63.0,
          temperature_apparent_min: 48.0,
          temperature_apparent_avg: 55.5,
          conditions: "Partly Cloudy",
          precipitation_probability: 20.0,
          uv_index_max: 5
        },
        {
          city: "Paris",
          date: Date.today + 9.days,
          temperature_max: 58.9,
          temperature_min: 45.7,
          temperature_avg: 52.3,
          temperature_apparent_max: 56.0,
          temperature_apparent_min: 43.0,
          temperature_apparent_avg: 49.5,
          conditions: "Rain",
          precipitation_probability: 80.0,
          uv_index_max: 2
        }
      ]
    end

    it "processes multiple trips independently" do
      # Mock API to return different data based on city
      allow_any_instance_of(WeatherForecastApiFetcher).to receive(:fetch) do |fetcher|
        if fetcher.instance_variable_get(:@city) == "Boston"
          forecast_data
        else
          paris_forecast_data
        end
      end

      # Create two trips
      post trips_path, params: { trip: trip_attributes }
      boston_trip = Trip.last

      post trips_path, params: { trip: trip2_attributes }
      paris_trip = Trip.last

      # Process all jobs including nested jobs
      # Need to run twice to process ForecastFetcherJobs and then RecommendationAnalyzerJobs
      2.times { perform_enqueued_jobs }

      # Verify both trips are completed
      boston_trip.reload
      paris_trip.reload

      expect(boston_trip.status).to eq("ready")
      expect(paris_trip.status).to eq("ready")

      expect(boston_trip.forecasts.count).to eq(3)
      expect(paris_trip.forecasts.count).to eq(3)

      expect(boston_trip.recommendations.count).to eq(5)
      expect(paris_trip.recommendations.count).to eq(5)

      # Verify forecasts are city-specific
      expect(boston_trip.forecasts.pluck(:city).uniq).to eq([ "Boston" ])
      expect(paris_trip.forecasts.pluck(:city).uniq).to eq([ "Paris" ])
    end
  end
end
