class Recommendation < ApplicationRecord
  CATEGORIES = %w[outerwear tops bottoms footwear accessories].freeze

  belongs_to :trip

  validates :clothing_category, presence: true, inclusion: { in: CATEGORIES }
  validates :details, presence: true
end
