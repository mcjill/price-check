# frozen_string_literal: true

require 'nokogiri'
require 'json'

module Scrapers
  class CompuGhana < Base
    BASE_URL = 'https://compughana.com'

    def scrape(query, min_price: nil, max_price: nil)
      url = "#{BASE_URL}/search?q=#{URI.encode_www_form_component(query)}"
      response = HttpFetcher.get(url)
      return [] unless response.is_a?(Net::HTTPSuccess)

      json_products = parse_shopify_meta(response.body, min_price, max_price)
      return json_products if json_products.any?

      doc = Nokogiri::HTML(response.body)
      products = []

      doc.css('.item.product.product-item, .product-item').each do |item|
        title = item.at_css('.product.name.product-item-name a')&.text.to_s.strip
        next if title.empty?

        price_text = item.at_css('.price, .regular-price, .special-price, .price-box .price')&.text.to_s.strip
        price = clean_price(price_text)
        next unless within_budget?(price, min_price, max_price)

        link = item.at_css('.product.name.product-item-name a')&.[]('href')
        image = item.at_css('.product-image-photo')&.[]('src') || item.at_css('.product-image-photo')&.[]('data-src')

        products << {
          title: title,
          price: price,
          currency: 'GHS',
          url: safe_url(BASE_URL, link.to_s),
          image_url: normalize_image(BASE_URL, image.to_s),
          store: 'CompuGhana'
        }
      end

      products
    rescue StandardError
      []
    end

    def parse_shopify_meta(html, min_price, max_price)
      match = html.match(/var meta = (\{.*?\});/m)
      return [] unless match

      meta = JSON.parse(match[1])
      products = meta['products'] || []

      products.first(30).filter_map do |product|
        variant = Array(product['variants']).first
        next unless variant

        price = (variant['price'].to_f / 100).round(2)
        next unless within_budget?(price, min_price, max_price)

        title = variant['name'] || product['title'] || product['handle']&.tr('-', ' ')
        handle = product['handle']

        image_url = fetch_product_image(product['handle'])

        {
          title: title.to_s,
          price: price,
          currency: 'GHS',
          url: safe_url(BASE_URL, "/products/#{handle}"),
          image_url: image_url,
          store: 'CompuGhana'
        }
      end
    rescue StandardError
      []
    end

    def fetch_product_image(handle)
      return '' if handle.to_s.empty?
      cache_key = "img:compughana:#{handle}"
      cached = ImageCache.get(cache_key)
      return cached if cached.present?

      response = HttpFetcher.get("#{BASE_URL}/products/#{handle}.js")
      return '' unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      image = Array(data['images']).first.to_s
      Rails.cache.write(cache_key, image, expires_in: ImageCache::CACHE_TTL) if image.present?
      image
    rescue StandardError
      ''
    end
  end
end
