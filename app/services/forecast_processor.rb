class ForecastProcessor
  class ProcessingError < StandardError; end
  def initialize(trip:)
    @trip = trip
  end

  def process
    # Determine which dates we need forecasts for
    date_range = (@trip.start_date..@trip.end_date).to_a

    # Check for existing forecasts and determine which need refreshing
    existing_forecasts = Forecast.where(city: @trip.city, date: date_range)
    fresh_forecasts = existing_forecasts.where.not.stale
    fresh_dates = fresh_forecasts.pluck(:date)

    # Fetch forecasts for dates that are missing or stale (updated >= 24 hours ago)
    dates_to_fetch = date_range - fresh_dates

    if dates_to_fetch.any?
      forecast_data = fetch_from_api
      create_forecasts(forecast_data)
    end

    # Link all forecasts to this trip via join table
    all_forecasts = Forecast.where(city: @trip.city, date: date_range)
    link_forecasts_to_trip(all_forecasts)

    all_forecasts
  rescue WeatherForecastApiFetcher::WeatherAPIError => e
    raise ProcessingError, "Failed to fetch weather data: #{e.message}"
  rescue ActiveRecord::RecordInvalid => e
    raise ProcessingError, "Failed to save forecast data: #{e.message}"
  end

  private

  def fetch_from_api
    fetcher = WeatherForecastApiFetcher.new(
      @trip.city,
      @trip.start_date,
      @trip.end_date
    )

    fetcher.fetch
  end

  def create_forecasts(forecast_data)
    # Use upsert_all for efficient bulk insert/update in a single database operation
    # This handles race conditions automatically and updates existing records
    # Add updated_at timestamp to each record for proper tracking
    timestamped_data = forecast_data.map do |data|
      data.merge(updated_at: Time.current)
    end

    Forecast.upsert_all(
      timestamped_data,
      unique_by: [ :city, :date ]
    )
  end

  def link_forecasts_to_trip(forecasts)
    forecasts.each do |forecast|
      # Use find_or_create_by to avoid duplicate join records
      TripForecast.find_or_create_by!(trip: @trip, forecast: forecast)
    end
  end
end
