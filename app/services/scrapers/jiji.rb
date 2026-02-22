# frozen_string_literal: true

require 'nokogiri'

module Scrapers
  class Jiji < Base
    BASE_URL = 'https://jiji.com.gh'

    CATEGORY_MAP = {
      'television' => 'tv-dvd-equipment',
      'smart tv' => 'tv-dvd-equipment',
      'led tv' => 'tv-dvd-equipment',
      'oled tv' => 'tv-dvd-equipment',
      'qled tv' => 'tv-dvd-equipment',
      'tv' => 'tv-dvd-equipment',
      'smartphone' => 'mobile-phones',
      'mobile phone' => 'mobile-phones',
      'phone' => 'mobile-phones',
      'mobile' => 'mobile-phones',
      'iphone' => 'mobile-phones',
      'samsung phone' => 'mobile-phones',
      'laptop' => 'computers-laptops',
      'computer' => 'computers-laptops',
      'tablet' => 'tablets',
      'ipad' => 'tablets',
      'headphone' => 'headphones',
      'earphone' => 'headphones',
      'speaker' => 'audio-and-music-equipment',
      'bluetooth' => 'audio-and-music-equipment',
      'camera' => 'cameras-camcorders',
      'watch' => 'watches',
      'gaming' => 'video-games-consoles',
      'console' => 'video-games-consoles',
      'keyboard' => 'computer-accessories',
      'mouse' => 'computer-accessories'
    }.freeze

    def scrape(query, min_price: nil, max_price: nil)
      category = category_for(query)
      url = if category
              "#{BASE_URL}/#{category}?query=#{URI.encode_www_form_component(query)}"
            else
              "#{BASE_URL}/search?query=#{URI.encode_www_form_component(query)}"
            end

      headers = {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer' => 'https://www.google.com/'
      }

      response = HttpFetcher.get(url, headers: headers)
      if !response.is_a?(Net::HTTPSuccess)
        fallback_url = "#{BASE_URL}/search?query=#{URI.encode_www_form_component(query)}"
        response = HttpFetcher.get(fallback_url, headers: headers)
      end

      return [] unless response.is_a?(Net::HTTPSuccess)

      doc = Nokogiri::HTML(response.body)
      items = doc.css('.qa-advert-list-item, .b-list-advert-base, .js-advert-list-item, article')
      if items.empty? && category
        fallback_url = "#{BASE_URL}/search?query=#{URI.encode_www_form_component(query)}"
        response = HttpFetcher.get(fallback_url, headers: headers)
        return [] unless response.is_a?(Net::HTTPSuccess)
        doc = Nokogiri::HTML(response.body)
      end
      products = []

      doc.css('.qa-advert-list-item, .b-list-advert-base, .js-advert-list-item, article').each_with_index do |item, index|
        title = extract_title(item)
        next if title.empty?

        price = extract_price(item)
        next unless within_budget?(price, min_price, max_price)

        link = extract_link(item)
        next if link.empty?

        image = extract_image(item)

        products << {
          title: title,
          price: price,
          currency: 'GHS',
          url: safe_url(BASE_URL, link),
          image_url: normalize_image(BASE_URL, image),
          store: 'Jiji'
        }

        break if index >= 40
      end

      products
    rescue StandardError
      []
    end

    private

    def category_for(query)
      sorted_keys = CATEGORY_MAP.keys.sort_by { |key| -key.length }
      match = sorted_keys.find { |key| query.downcase.include?(key) }
      match ? CATEGORY_MAP[match] : nil
    end

    def extract_title(item)
      selectors = [
        '.qa-advert-title',
        '.b-list-advert-base__data__title',
        '.b-advert-title-inner',
        '[class*="title"]',
        'h3',
        'h4',
        'h5'
      ]
      selectors.each do |selector|
        text = item.at_css(selector)&.text.to_s.strip
        return text unless text.empty?
      end
      ''
    end

    def extract_price(item)
      selectors = ['.qa-advert-price', '.b-list-advert-base__data__price', '.b-advert-price', '.b-list-advert__price', '[class*="price"]']
      selectors.each do |selector|
        text = item.at_css(selector)&.text.to_s.strip
        price = clean_price(text)
        return price if price.positive?
      end

      text = item.text
      match = text.match(/GH[S₵]?\s*[\d,]+(?:\.\d{2})?|[\d,]+(?:\.\d{2})?\s*GH[S₵]?|₵\s*[\d,]+(?:\.\d{2})?/i)
      return 0 unless match

      clean_price(match[0])
    end

    def extract_link(item)
      link = item.at_css('a[href*=".html"]')&.[]('href')
      link ||= item.at_css('a[href]')&.[]('href')
      link.to_s
    end

    def extract_image(item)
      img = item.at_css('img')
      return '' unless img

      %w[data-src src data-lazy].each do |attr|
        val = img[attr].to_s
        return val unless val.empty? || val.include?('placeholder')
      end
      ''
    end
  end
end
