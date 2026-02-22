class PriceHistory < ApplicationRecord
  belongs_to :product

  validates :price, :currency, :scraped_at, presence: true
end
