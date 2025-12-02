FactoryBot.define do
  factory :weather_forecast do
    date { "2025-12-02" }
    temperature_apparent_avg { 61.0 }
    temperature_apparent_max { 71.0 }
    temperature_apparent_min { 81.0 }
    uv_index_max { 5 }
    # weather codes come from https://docs.tomorrow.io/reference/data-layers-weather-codes
    weather_code_min { 1000 }
    weather_code_max { 1000 }
    temperature_avg { 60.0 }
    temperature_max { 70.0 }
    temperature_min { 80.0 }
  end
end
