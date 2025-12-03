FactoryBot.define do
  factory :trip do
    start_date { "2025-01-01" }
    end_date { "2025-01-01" }
    city { "Test City" }
    status { :pending }
  end
end
