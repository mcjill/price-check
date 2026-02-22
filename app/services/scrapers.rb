# frozen_string_literal: true

require_relative 'scrapers/base'
require_relative 'scrapers/jumia'
require_relative 'scrapers/jiji'
require_relative 'scrapers/compughana'
require_relative 'scrapers/telefonika'
require_relative 'scrapers/amazon'

module Scrapers
  REGISTRY = {
    'Jumia' => Jumia,
    'Jiji' => Jiji,
    'CompuGhana' => CompuGhana,
    'Telefonika' => Telefonika,
    # 'Amazon' => Amazon
  }.freeze

  def self.for(stores)
    requested = Array(stores).map(&:to_s)
    targets = requested.empty? ? REGISTRY.keys : requested
    targets.filter_map { |store| REGISTRY[store] }.map(&:new)
  end
end
