# frozen_string_literal: true

require 'nokogiri'
require 'open3'
require 'json'

module Scrapers
  class Amazon < Base
    BASE_URL = 'https://www.amazon.com'
    USD_TO_GHS = 12.5

    def scrape(query, min_price: nil, max_price: nil)
      products = []
      begin
        url = "#{BASE_URL}/s?k=#{URI.encode_www_form_component(query)}"
        response = HttpFetcher.get(url, headers: {
          'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        })

        if response.is_a?(Net::HTTPSuccess)
          body = response.body
          ghs_page = body.include?('GHS')
          doc = Nokogiri::HTML(body)

          doc.css('.s-result-item').each do |item|
            title = item.at_css('h2 span')&.text.to_s.strip
            next if title.empty?

            whole = item.at_css('.a-price-whole')&.text.to_s.strip
            fraction = item.at_css('.a-price-fraction')&.text.to_s.strip
            price_text = [whole, fraction].reject(&:empty?).join('.')
            price = clean_price(price_text)
            price = (price * USD_TO_GHS).round(2) unless ghs_page
            next unless within_budget?(price, min_price, max_price)

            link = item.at_css('a.a-link-normal')&.[]('href')
            image = item.at_css('img.s-image')&.[]('src')

            products << {
              title: title,
              price: price,
              currency: 'GHS',
              url: safe_url(BASE_URL, link.to_s),
              image_url: normalize_image(BASE_URL, image.to_s),
              store: 'Amazon'
            }
          end
        end
      rescue StandardError
        products = []
      end

      return products if products.any?

      scrape_with_playwright(query, min_price, max_price)
    rescue StandardError
      []
    end

    def scrape_with_playwright(query, min_price, max_price)
      script = Rails.root.join('scripts', 'playwright_scrape.mjs')
      return [] unless File.exist?(script)

      stdout, _stderr, status = Open3.capture3('node', script.to_s, 'Amazon', query.to_s)
      return [] unless status.success?

      data = JSON.parse(stdout)
      data.filter_map do |item|
        price = clean_price(item['priceText'].to_s)
        next unless within_budget?(price, min_price, max_price)

        {
          title: item['title'].to_s,
          price: price,
          currency: 'GHS',
          url: item['url'].to_s,
          image_url: item['image_url'].to_s,
          store: 'Amazon'
        }
      end
    rescue StandardError
      []
    end
  end
end
