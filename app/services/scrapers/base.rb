# frozen_string_literal: true

require 'nokogiri'
require 'uri'

module Scrapers
  class Base
    def scrape(_query, _min_price: nil, _max_price: nil)
      raise NotImplementedError
    end

    protected

    def clean_price(price_text)
      return 0 if price_text.to_s.strip.empty?

      cleaned = price_text.gsub(/[GH₵,\s]/, '').gsub(/[^0-9.]/, '')
      cleaned = cleaned.split('.').first if cleaned.count('.') > 1
      cleaned.to_f
    end

    def within_budget?(price, min_price, max_price)
      return false if price <= 0
      return false if min_price && price < min_price
      return false if max_price && price > max_price

      true
    end

    def safe_url(base, href)
      return '' if href.to_s.strip.empty?
      return href if href.start_with?('http')

      "#{base}#{href}"
    end

    def normalize_image(base, src)
      return '' if src.to_s.strip.empty?
      return src if src.start_with?('http')
      return "https:#{src}" if src.start_with?('//')

      "#{base}#{src}"
    end
  end
end
