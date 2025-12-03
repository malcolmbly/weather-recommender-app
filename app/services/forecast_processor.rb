class ForecastProcessor
  class ProcessingError < StandardError; end

  def initialize(trip:)
    @trip = trip
  end

  def process
    # Determine which dates we need forecasts for
    date_range = (@trip.start_date..@trip.end_date).to_a

    # Check for existing forecasts (deduplication)
    existing_forecasts = Forecast.where(city: @trip.city, date: date_range)
    existing_dates = existing_forecasts.pluck(:date)
    missing_dates = date_range - existing_dates

    # Fetch only missing forecasts from API if needed
    if missing_dates.any?
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
    forecast_data.each do |data|
      # Use find_or_create_by to handle race conditions
      Forecast.find_or_create_by!(city: data[:city], date: data[:date]) do |forecast|
        forecast.assign_attributes(
          temperature_max: data[:temperature_max],
          temperature_min: data[:temperature_min],
          temperature_avg: data[:temperature_avg],
          temperature_apparent_max: data[:temperature_apparent_max],
          temperature_apparent_min: data[:temperature_apparent_min],
          temperature_apparent_avg: data[:temperature_apparent_avg],
          conditions: data[:conditions],
          precipitation_probability: data[:precipitation_probability],
          uv_index_max: data[:uv_index_max]
        )
      end
    end
  end

  def link_forecasts_to_trip(forecasts)
    forecasts.each do |forecast|
      # Use find_or_create_by to avoid duplicate join records
      TripForecast.find_or_create_by!(trip: @trip, forecast: forecast)
    end
  end
end
