class TripsController < ApplicationController
  def index
    @trips = Trip.all
  end

  def new
    @trip = Trip.new
  end

  def create
    @trip = Trip.new(trip_params)
    if @trip.save
      redirect_to @trip
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @trip = Trip.find(params[:id])
  end

  def destroy
    Trip.find(params[:id]).destroy
  end

  private
  def trip_params
    params.expect(trip: [ :start_date, :end_date, :city ])
  end
end
