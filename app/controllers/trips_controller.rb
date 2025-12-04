class TripsController < ApplicationController
  def index
    @trips = Trip.all.order(created_at: :desc)
  end

  def new
    @trip = Trip.new
  end

  def create
    @trip = Trip.new(trip_params)
    if @trip.save
      # Enqueue background job to fetch weather and generate recommendations
      ForecastFetcherJob.perform_later(@trip.id)

      redirect_to @trip, notice: "Trip created! Fetching weather data and generating recommendations..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Eager load associations to avoid N+1 queries
    @trip = Trip.includes(:forecasts, :recommendations).find(params[:id])
  end

  def destroy
    Trip.find(params[:id]).destroy
    redirect_to trips_path, notice: "Trip deleted."
  end

  private
  def trip_params
    params.expect(trip: [ :start_date, :end_date, :city ])
  end
end
