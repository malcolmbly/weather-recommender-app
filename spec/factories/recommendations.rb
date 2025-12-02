FactoryBot.define do
  factory :recommendation do
    trip { nil }
    clothing_category { "outerwear" }
    details { "outerwear description" }
  end
end
