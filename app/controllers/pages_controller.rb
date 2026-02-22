# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @stores = Scrapers::REGISTRY.keys
    @results = SearchService::Result.new(high: [], other: [])
  end
end
