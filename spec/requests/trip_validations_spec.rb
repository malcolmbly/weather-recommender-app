# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Trip Validations and Edge Cases", type: :request do
  describe "Trip date validations" do
    context "with invalid date ranges" do
      it "rejects trip when end_date is before start_date" do
        trip_params = {
          city: "Boston",
          start_date: Date.today,
          end_date: Date.yesterday
        }

        post trips_path, params: { trip: trip_params }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("End date must be on or after start date")
      end

      it "rejects trip when duration exceeds 14 days" do
        trip_params = {
          city: "Boston",
          start_date: Date.today,
          end_date: Date.today + 15.days
        }

        post trips_path, params: { trip: trip_params }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Trip duration must be between 1 and 14 days")
      end
    end

    context "with valid edge case dates" do
      it "accepts single-day trip (start_date equals end_date)" do
        trip_params = {
          city: "Boston",
          start_date: Date.today,
          end_date: Date.today
        }

        expect {
          post trips_path, params: { trip: trip_params }
        }.to change(Trip, :count).by(1)

        expect(response).to redirect_to(trip_path(Trip.last))
      end

      it "accepts maximum 14-day trip" do
        trip_params = {
          city: "Boston",
          start_date: Date.today,
          end_date: Date.today + 13.days
        }

        expect {
          post trips_path, params: { trip: trip_params }
        }.to change(Trip, :count).by(1)

        trip = Trip.last
        duration = (trip.end_date - trip.start_date).to_i + 1
        expect(duration).to eq(14)
      end
    end
  end

  describe "City validation" do
    it "rejects trip with blank city" do
      trip_params = {
        city: "",
        start_date: Date.today,
        end_date: Date.today + 3.days
      }

      post trips_path, params: { trip: trip_params }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("can&#39;t be blank")
    end

    it "accepts trip with various city formats" do
      cities = [ "Boston", "New York", "San Francisco", "Tokyo", "Paris" ]

      cities.each do |city|
        trip_params = {
          city: city,
          start_date: Date.today,
          end_date: Date.today + 2.days
        }

        expect {
          post trips_path, params: { trip: trip_params }
        }.to change(Trip, :count).by(1)
      end
    end
  end

  describe "Missing parameters" do
    it "rejects trip with missing start_date" do
      trip_params = {
        city: "Boston",
        end_date: Date.today + 3.days
      }

      post trips_path, params: { trip: trip_params }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects trip with missing end_date" do
      trip_params = {
        city: "Boston",
        start_date: Date.today
      }

      post trips_path, params: { trip: trip_params }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "Trip show page edge cases" do
    context "with non-existent trip ID" do
      it "returns 404 not found status" do
        get trip_path(id: 99999)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with trip in various states" do
      let(:trip) { create(:trip, city: "Boston") }

      it "displays trip in pending state correctly" do
        trip.update!(status: :pending)

        get trip_path(trip)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Pending")
      end

      it "displays trip in processing state correctly" do
        trip.update!(status: :processing)

        get trip_path(trip)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Processing")
      end

      it "displays trip in failed state correctly" do
        trip.update!(status: :failed)

        get trip_path(trip)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Failed")
      end

      it "displays trip in ready state correctly" do
        trip.update!(status: :ready)

        get trip_path(trip)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Ready")
      end
    end

    context "with partial data" do
      let(:trip) { create(:trip, city: "Boston", start_date: Date.today, end_date: Date.today + 2.days) }

      it "handles trip with forecasts but no recommendations" do
        forecast = Forecast.create!(
          city: "Boston",
          date: Date.today,
          temperature_max: 75.5,
          temperature_min: 55.2,
          temperature_avg: 65.3,
          temperature_apparent_max: 73.0,
          temperature_apparent_min: 53.0,
          temperature_apparent_avg: 63.0,
          conditions: "Clear",
          precipitation_probability: 10.0,
          uv_index_max: 5
        )
        trip.forecasts << forecast

        get trip_path(trip)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Weather Forecast")
        expect(response.body).to include("76°F")  # Rounded from 75.5
        expect(response.body).to include("Clear")
      end

      it "handles trip with recommendations but no forecasts" do
        Recommendation.create!(
          trip: trip,
          clothing_category: "outerwear",
          details: "Light jacket"
        )

        get trip_path(trip)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Light jacket")
      end
    end
  end

  describe "Trips index page edge cases" do
    it "handles empty trips list" do
      get trips_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Trips")
    end

    it "displays multiple trips with various statuses" do
      create(:trip, city: "Boston", status: :pending)
      create(:trip, city: "Paris", status: :processing)
      create(:trip, city: "Tokyo", status: :ready)
      create(:trip, city: "London", status: :failed)

      get trips_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Boston")
      expect(response.body).to include("Paris")
      expect(response.body).to include("Tokyo")
      expect(response.body).to include("London")
    end
  end

  describe "Trip deletion edge cases" do
    it "handles deletion of non-existent trip" do
      delete trip_path(id: 99999)
      expect(response).to have_http_status(:not_found)
    end

    it "properly cascades deletion to recommendations" do
      trip = create(:trip)
      create_list(:recommendation, 3, trip: trip)

      expect {
        delete trip_path(trip)
      }.to change(Recommendation, :count).by(-3)
    end

    it "does not delete shared forecasts" do
      trip1 = create(:trip, city: "Boston", start_date: Date.today, end_date: Date.today + 1.day)
      trip2 = create(:trip, city: "Boston", start_date: Date.today, end_date: Date.today + 1.day)

      forecast = Forecast.create!(
        city: "Boston",
        date: Date.today,
        temperature_max: 75.5,
        temperature_min: 55.2,
        temperature_avg: 65.3,
        temperature_apparent_max: 73.0,
        temperature_apparent_min: 53.0,
        temperature_apparent_avg: 63.0,
        conditions: "Clear",
        precipitation_probability: 10.0,
        uv_index_max: 5
      )

      trip1.forecasts << forecast
      trip2.forecasts << forecast

      expect {
        delete trip_path(trip1)
      }.not_to change(Forecast, :count)

      # Verify the forecast is still associated with trip2
      expect(trip2.reload.forecasts).to include(forecast)
    end
  end

  describe "Concurrent trip creation" do
    it "allows multiple trips with same city and overlapping dates" do
      trip_params = {
        city: "Boston",
        start_date: Date.today,
        end_date: Date.today + 3.days
      }

      # Create first trip
      post trips_path, params: { trip: trip_params }
      trip1 = Trip.last

      # Create second trip with identical parameters
      post trips_path, params: { trip: trip_params }
      trip2 = Trip.last

      expect(trip1.id).not_to eq(trip2.id)
      expect(trip1.city).to eq(trip2.city)
      expect(trip1.start_date).to eq(trip2.start_date)
      expect(trip1.end_date).to eq(trip2.end_date)
    end
  end
end
