class Product < ApplicationRecord
  has_many :price_histories, dependent: :destroy

  validates :name, :source, :currency, presence: true

  def latest_price
    price_histories.order(scraped_at: :desc).first
  end
end
