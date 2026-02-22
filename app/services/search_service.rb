# frozen_string_literal: true

require 'nokogiri'

class SearchService
  HIGH_RELEVANCY_THRESHOLD = 0.6

  Result = Struct.new(:high, :other, keyword_init: true)

  def self.search(query:, min_price: nil, max_price: nil, stores: [])
    new(query: query, min_price: min_price, max_price: max_price, stores: stores).search
  end

  def initialize(query:, min_price:, max_price:, stores: [])
    @query = query.to_s.strip
    @min_price = min_price
    @max_price = max_price
    @stores = Array(stores).presence || Scrapers::REGISTRY.keys
  end

  def search
    return Result.new(high: [], other: []) if @query.empty?

    products = scrape_all
    scored = products.map { |product| enrich_product(product) }
    filtered = scored.select do |product|
      product[:relevancy_score].to_f.positive? &&
        RelevancyScorer.matches_query?(title: product[:title], query: @query)
    end
    pool = filtered.empty? ? scored : filtered
    sorted = pool.sort_by { |product| product[:price].to_f }

    persist_results(sorted)

    Result.new(high: sorted, other: [])
  end

  private

  def scrape_all
    scrapers = Scrapers.for(@stores)

    threads = scrapers.map do |scraper|
      Thread.new do
        results = scraper.scrape(@query, min_price: @min_price, max_price: @max_price)
        Rails.logger.info("[Scraper] #{scraper.class.name} returned #{results.length} products")
        results
      rescue StandardError
        Rails.logger.warn("[Scraper] #{scraper.class.name} failed")
        []
      end
    end

    threads.flat_map(&:value).compact
  end

  def enrich_product(product)
    score = RelevancyScorer.score(title: product[:title], query: @query)
    product.merge(relevancy_score: score || 0.0)
  end

  def persist_results(products)
    return if ENV['SKIP_DB'] == '1'
    begin
      ActiveRecord::Base.connection
    rescue ActiveRecord::ConnectionNotEstablished
      return
    rescue StandardError => e
      return if e.class.name == 'PG::ConnectionBad'
      raise
    end

    products.each do |product|
      record = find_or_create_product(product)
      next unless record

      record.price_histories.create!(
        price: product[:price],
        currency: product[:currency],
        scraped_at: Time.current
      )
    rescue StandardError
      next
    end
  end

  def find_or_create_product(product)
    url = product[:url].presence
    source = product[:store]

    record = if url
               Product.find_by(source: source, url: url)
             else
               Product.find_by(source: source, name: product[:title])
             end

    record ||= Product.new(source: source, url: url)
    record.name = product[:title]
    record.image_url = product[:image_url]
    record.currency = product[:currency]
    record.save! if record.changed?
    record
  end
end
