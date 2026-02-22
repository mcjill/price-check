# frozen_string_literal: true

class RelevancyScorer
  MIN_RELEVANCY_SCORE = 0.2

  PRODUCT_BRANDS = {
    phones: %w[iphone samsung huawei xiaomi tecno infinix oppo vivo realme].freeze,
    laptops: %w[hp dell lenovo acer asus apple macbook toshiba msi].freeze,
    appliances: %w[lg samsung whirlpool panasonic philips binatone bruhm nasco zara].freeze,
    electronics: %w[sony lg samsung panasonic philips tcl hisense toshiba].freeze,
    kitchen: %w[binatone philips zara nasco bruhm kenwood geepas raf].freeze
  }.freeze

  NOISE_WORDS = {
    phones: %w[case cover protector charger cable adapter holder stand].freeze,
    laptops: %w[bag sleeve charger adapter stand cooling pad skin].freeze,
    appliances: %w[cover manual accessory spare part filter].freeze,
    electronics: %w[mount stand cable remote bracket holder].freeze,
    kitchen: %w[spare part attachment accessory manual].freeze
  }.freeze

  STOP_WORDS = %w[the a an for with and or of to in on at by from].freeze

  def self.score(title:, query:)
    return 0 if title.to_s.strip.empty? || query.to_s.strip.empty?

    title_lower = title.downcase
    query_lower = query.downcase
    search_terms = normalized_terms(query_lower)
    accessory_query = (NOISE_WORDS.values.flatten & search_terms).any?

    sanitized_title = title_lower.dup
    unless accessory_query
      NOISE_WORDS.values.flatten.each do |word|
        sanitized_title.gsub!(/\b#{Regexp.escape(word)}\b/i, '')
      end
      sanitized_title = sanitized_title.gsub(/\s+/, ' ').strip
    end

    matched_terms = search_terms.select { |term| sanitized_title.include?(term) }
    term_match_count = matched_terms.length
    is_exact_match = term_match_count == search_terms.length

    brand = PRODUCT_BRANDS.values.flatten.find { |b| title_lower.include?(b) }

    model_patterns = [
      /\b\d+(\s?pro)?(\s?max)?(\s?plus)?(\s?ultra)?/i,
      /\b[a-z]\d+[a-z]?\b/i,
      /\b[a-z]{1,3}-?\d{2,4}[a-z]?\b/i
    ]
    model = model_patterns.map { |pattern| title_lower.match(pattern) }.compact.first&.[](0)

    score = 0.0
    score += (term_match_count.to_f / [search_terms.length, 1].max) * 5
    score += 3 if is_exact_match
    score += 2 if brand && search_terms.include?(brand)
    score += 2 if model && search_terms.any? { |term| model.include?(term) }

    title_words = sanitized_title.split(' ').length
    length_score = [0, 1 - (title_words - search_terms.length) / 10.0].max
    score += length_score

    score += 2 if sanitized_title.include?(query_lower)

    is_accessory = NOISE_WORDS.values.flatten.any? { |word| title_lower.include?(word) }
    score *= 0.3 if is_accessory && !accessory_query

    normalized_score = [1, score / 13.0].min
    threshold = accessory_query ? 0.05 : MIN_RELEVANCY_SCORE
    normalized_score >= threshold ? normalized_score : 0
  end

  def self.matches_query?(title:, query:)
    return false if title.to_s.strip.empty? || query.to_s.strip.empty?

    title_lower = title.downcase
    query_lower = query.downcase
    terms = normalized_terms(query_lower)
    title_terms = normalized_terms(title_lower)

    return false if terms.empty?

    if query_lower.include?('type c')
      return false unless title_lower.include?('type c') || title_lower.include?('usb c') || title_lower.include?('usbc')
    end
    if query_lower.include?('usb c')
      return false unless title_lower.include?('usb c') || title_lower.include?('type c') || title_lower.include?('usbc')
    end
    if query_lower.include?('usbc')
      return false unless title_lower.include?('usbc') || title_lower.include?('usb c') || title_lower.include?('type c')
    end

    overlap = terms.count { |term| title_terms.include?(term) }
    min_required = terms.length <= 2 ? terms.length : (terms.length - 1)
    ratio = overlap.to_f / terms.length

    overlap >= min_required || ratio >= 0.6
  end

  def self.normalized_terms(query_lower)
    tokens = query_lower.scan(/[a-z0-9]+/)
    tokens = tokens.map do |token|
      if token.length > 3 && token.end_with?('s')
        token[0..-2]
      else
        token
      end
    end
    tokens.reject { |token| token.length < 2 || STOP_WORDS.include?(token) }
  end
end
