# frozen_string_literal: true

require 'nokogiri'
require 'open3'
require 'json'

module Scrapers
  class Jumia < Base
    BASE_URL = 'https://www.jumia.com.gh'

    def scrape(query, min_price: nil, max_price: nil)
      mobile_url = "#{BASE_URL}/catalog/?q=#{URI.encode_www_form_component(query)}"
      headers = {
        'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1'
      }

      products = parse_products(mobile_url, headers, min_price, max_price)
      return products if products.any?

      desktop_headers = {
        'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      }
      products = parse_products(mobile_url, desktop_headers, min_price, max_price)
      return products if products.any?

      scrape_with_playwright(query, min_price, max_price)
    rescue StandardError
      []
    end

    private

    def parse_products(url, headers, min_price, max_price)
      response = HttpFetcher.get(url, headers: headers)
      return [] unless response.is_a?(Net::HTTPSuccess)

      doc = Nokogiri::HTML(response.body)
      products = []

      doc.css('article.prd, article, .prd, .product, [data-product], .item').each do |item|
        title = extract_title(item)
        next if title.empty?

        price_text = extract_text(item, ['div.prc', '.prc', '.price', '.amount', '.current-price', '.prd-price'])
        price = clean_price(price_text)
        next unless within_budget?(price, min_price, max_price)

        link = extract_link(item)
        image = extract_image(item)

        products << {
          title: title,
          price: price,
          currency: 'GHS',
          url: safe_url(BASE_URL, link),
          image_url: normalize_image(BASE_URL, image),
          store: 'Jumia'
        }
      end

      products
    end

    def extract_title(item)
      selectors = ['[data-name]', '.name', '.title', '.product-name', '.product-title', 'h3', 'h4', '.prd-name', '.item-name']
      selectors.each do |selector|
        node = item.at_css(selector)
        text = node&.[]('data-name').to_s.strip
        text = node&.text.to_s.strip if text.empty?
        return text unless text.empty?
      end
      item.at_css('a')&.[]('title').to_s.strip
    end

    def extract_text(item, selectors)
      selectors.each do |selector|
        text = item.at_css(selector)&.text.to_s.strip
        return text unless text.empty?
      end
      ''
    end

    def extract_link(item)
      link = item.at_css('a.core')&.[]('href')
      link ||= item.at_css('a[href*="/product/"]')&.[]('href')
      link ||= item.at_css('a[href*="/products/"]')&.[]('href')
      link ||= item.at_css('a')&.[]('href')
      link.to_s
    end

    def extract_image(item)
      img = item.at_css('img')
      return '' unless img

      %w[data-src src data-lazy data-original data-img data-image].each do |attr|
        val = img[attr].to_s
        return val unless val.empty? || val.include?('data:image') || val.include?('placeholder') || val.include?('svg')
      end
      ''
    end

    def scrape_with_playwright(query, min_price, max_price)
      script = Rails.root.join('scripts', 'playwright_scrape.mjs')
      return [] unless File.exist?(script)

      stdout, _stderr, status = Open3.capture3('node', script.to_s, 'Jumia', query.to_s)
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
          store: 'Jumia'
        }
      end
    rescue StandardError
      []
    end
  end
end
