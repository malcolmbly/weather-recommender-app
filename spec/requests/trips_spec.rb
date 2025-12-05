# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Trips", type: :request do
  describe "GET /trips" do
    it "returns success and displays all trips" do
      create_list(:trip, 3)

      get trips_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("My Trips")
    end

    it "displays trips in descending order by creation date" do
      older_trip = create(:trip, city: "Boston", created_at: 2.days.ago)
      newer_trip = create(:trip, city: "Paris", created_at: 1.day.ago)

      get trips_path

      expect(response.body.index("Paris")).to be < response.body.index("Boston")
    end
  end

  describe "GET /trips/new" do
    it "returns success and displays the new trip form" do
      get new_trip_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Plan Your Trip")
      expect(response.body).to include("City")
      expect(response.body).to include("Start Date")
      expect(response.body).to include("End Date")
    end
  end

  describe "POST /trips" do
    let(:valid_attributes) do
      {
        city: "Boston",
        start_date: Date.today,
        end_date: Date.today + 3.days
      }
    end

    let(:invalid_attributes) do
      {
        city: "",
        start_date: Date.today,
        end_date: Date.yesterday
      }
    end

    context "with valid parameters" do
      it "creates a new trip" do
        expect {
          post trips_path, params: { trip: valid_attributes }
        }.to change(Trip, :count).by(1)
      end

      it "sets the trip status to pending" do
        post trips_path, params: { trip: valid_attributes }

        trip = Trip.last
        expect(trip.status).to eq("pending")
      end

      it "enqueues a ForecastFetcherJob" do
        expect {
          post trips_path, params: { trip: valid_attributes }
        }.to have_enqueued_job(ForecastFetcherJob).with(kind_of(Integer))
      end

      it "redirects to the trip show page" do
        post trips_path, params: { trip: valid_attributes }

        trip = Trip.last
        expect(response).to redirect_to(trip_path(trip))
      end

      it "displays a success notice" do
        post trips_path, params: { trip: valid_attributes }

        follow_redirect!
        expect(response.body).to include("Trip created!")
      end
    end

    context "with invalid parameters" do
      it "does not create a new trip" do
        expect {
          post trips_path, params: { trip: invalid_attributes }
        }.not_to change(Trip, :count)
      end

      it "does not enqueue a ForecastFetcherJob" do
        expect {
          post trips_path, params: { trip: invalid_attributes }
        }.not_to have_enqueued_job(ForecastFetcherJob)
      end

      it "renders the new template with unprocessable_entity status" do
        post trips_path, params: { trip: invalid_attributes }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Plan Your Trip")
      end

      it "displays validation errors" do
        post trips_path, params: { trip: invalid_attributes }

        expect(response.body).to include("can&#39;t be blank")
      end
    end
  end

  describe "GET /trips/:id" do
    let(:trip) { create(:trip, city: "Boston", start_date: Date.today, end_date: Date.today + 2.days) }

    context "when trip has no forecasts or recommendations yet" do
      it "returns success and displays the trip details" do
        get trip_path(trip)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Boston")
        expect(response.body).to include(trip.start_date.strftime("%B %d, %Y"))
      end

      it "displays pending status" do
        trip.update!(status: :pending)

        get trip_path(trip)

        expect(response.body).to include("Pending")
      end
    end

    context "when trip has forecasts" do
      let!(:forecast1) do
        Forecast.create!(
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
        )
      end

      let!(:forecast2) do
        Forecast.create!(
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
        )
      end

      before do
        trip.forecasts << [ forecast1, forecast2 ]
        trip.update!(status: :ready)
        trip.reload # Ensure associations are fresh
      end

      it "displays weather forecast table" do
        get trip_path(trip)

        expect(response.body).to include("Weather Forecast")
        expect(response.body).to include("Clear, Sunny")
        expect(response.body).to include("Rain")
        expect(response.body).to include("76") # Rounded from 75.5
        expect(response.body).to include("69") # Rounded from 68.8
      end
    end

    context "when trip has recommendations" do
      let!(:recommendations) do
        [
          { clothing_category: "outerwear", details: "Light jacket recommended" },
          { clothing_category: "tops", details: "Long-sleeve shirts" },
          { clothing_category: "bottoms", details: "Jeans or casual pants" },
          { clothing_category: "footwear", details: "Comfortable walking shoes" },
          { clothing_category: "accessories", details: "Sunglasses and sunscreen" }
        ].map { |attrs| Recommendation.create!(attrs.merge(trip: trip)) }
      end

      before do
        trip.update!(status: :ready)
      end

      it "displays all clothing recommendations" do
        get trip_path(trip)

        expect(response.body).to include("Packing Recommendations")
        expect(response.body).to include("Light jacket recommended")
        expect(response.body).to include("Long-sleeve shirts")
        expect(response.body).to include("Jeans or casual pants")
        expect(response.body).to include("Comfortable walking shoes")
        expect(response.body).to include("Sunglasses and sunscreen")
      end

      it "displays ready status" do
        get trip_path(trip)

        expect(response.body).to include("Ready")
      end
    end

    context "when trip is processing" do
      before do
        trip.update!(status: :processing)
      end

      it "displays processing status" do
        get trip_path(trip)

        expect(response.body).to include("Processing")
      end
    end

    context "when trip has failed" do
      before do
        trip.update!(status: :failed)
      end

      it "displays failed status" do
        get trip_path(trip)

        expect(response.body).to include("Failed")
      end
    end
  end

  describe "DELETE /trips/:id" do
    let!(:trip) { create(:trip) }

    it "deletes the trip" do
      expect {
        delete trip_path(trip)
      }.to change(Trip, :count).by(-1)
    end

    it "redirects to the trips index" do
      delete trip_path(trip)

      expect(response).to redirect_to(trips_path)
    end

    it "displays a success notice" do
      delete trip_path(trip)

      follow_redirect!
      expect(response.body).to include("Trip deleted")
    end

    context "when trip has associated forecasts and recommendations" do
      let!(:forecast) do
        Forecast.create!(
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
      end

      let!(:recommendation) do
        Recommendation.create!(
          trip: trip,
          clothing_category: "outerwear",
          details: "Light jacket"
        )
      end

      before do
        trip.forecasts << forecast
      end

      it "deletes associated recommendations" do
        expect {
          delete trip_path(trip)
        }.to change(Recommendation, :count).by(-1)
      end

      it "removes trip_forecast associations but keeps forecast records" do
        expect {
          delete trip_path(trip)
        }.to change(TripForecast, :count).by(-1)
         .and change(Forecast, :count).by(0)
      end
    end
  end
end
