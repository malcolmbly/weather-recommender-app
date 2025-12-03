require "httparty"

class WeatherForecastApiFetcher
  class WeatherAPIError < StandardError; end
  BASE_URL = "https://api.tomorrow.io/v4/weather/forecast"

  def self.fetch_current_weather(city, start_date, end_date)
    new(city, start_date, end_date).fetch
  end

  def initialize(city, start_date, end_date)
    @city = city
    @start_date = start_date
    @end_date = end_date
  end

  def fetch
    response = make_request
    parse_response(response)
  rescue HTTParty::Error, SocketError, Timeout::Error => e
    raise WeatherAPIError, "Failed to fetch weather data: #{e.message}"
  end

  private

  def make_request
    response = HTTParty.get(
      BASE_URL,
      query: generate_query,
      headers: {
        "accept" => "application/json"
      },
      timeout: 10
    )

    raise WeatherAPIError, "API returned #{response.code}: #{response.body}" unless response.success?

    response
  end

  def generate_query
    {
      location: @city, # HTTParty handles URL encoding (e.g., %20 for space)
      timesteps: "1d",
      units: "imperial",
      apikey: api_key
    }
  end

  def api_key
    ENV["WEATHER_API_KEY"] || Rails.application.credentials.dig(:external_apis, :weather_forecast, :api_key)
  end

  def parse_response(response)
    daily_data = response.parsed_response.dig("timelines", "daily")

    raise WeatherAPIError, "Invalid API response structure" if daily_data.nil?

    daily_data.filter_map do |day|
      date = Date.parse(day["time"])
      values = day["values"]

      # API returns next 5 days regardless of requested range, so filter to requested dates
      next unless date.between?(@start_date, @end_date)

      {
        city: @city,
        date: date,
        temperature_max: values["temperatureMax"]&.round(1),
        temperature_min: values["temperatureMin"]&.round(1),
        temperature_avg: values["temperatureAvg"]&.round(1),
        temperature_apparent_max: values["temperatureApparentMax"]&.round(1),
        temperature_apparent_min: values["temperatureApparentMin"]&.round(1),
        temperature_apparent_avg: values["temperatureApparentAvg"]&.round(1),
        conditions: map_weather_code(values["weatherCodeMax"]),
        precipitation_probability: values["precipitationProbabilityMax"]&.round(1),
        uv_index_max: values["uvIndexMax"]
      }
    end
  end

  def map_weather_code(code)
    return "Unknown" if code.nil?

    weather_codes[code] || weather_codes[0]
  end

  def weather_codes
    @weather_codes ||= YAML.load_file(Rails.root.join("config", "tomorrow_weather_codes.yml"))
  end
end
