FactoryBot.define do
  factory :forecast do
    city { "Boston" }
    date { Date.today }
    temperature_max { 70.0 }
    temperature_min { 55.0 }
    temperature_avg { 62.5 }
    temperature_apparent_max { 68.0 }
    temperature_apparent_min { 53.0 }
    temperature_apparent_avg { 60.5 }
    conditions { "Clear" }
    precipitation_probability { 10.0 }
    uv_index_max { 5 }

    trait :cold do
      temperature_max { 45.0 }
      temperature_min { 32.0 }
      temperature_avg { 38.5 }
      temperature_apparent_max { 40.0 }
      temperature_apparent_min { 28.0 }
      temperature_apparent_avg { 34.0 }
      conditions { "Cloudy" }
    end

    trait :hot do
      temperature_max { 95.0 }
      temperature_min { 78.0 }
      temperature_avg { 86.5 }
      temperature_apparent_max { 98.0 }
      temperature_apparent_min { 80.0 }
      temperature_apparent_avg { 89.0 }
      conditions { "Clear" }
    end

    trait :rainy do
      conditions { "Rain" }
      precipitation_probability { 75.0 }
    end
  end
end
