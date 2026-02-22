# frozen_string_literal: true

class SearchesController < ApplicationController
  def create
    query = params[:query].to_s
    min_price = params[:min_price].presence&.to_f
    max_price = params[:max_price].presence&.to_f
    stores = Array(params[:stores]).reject(&:blank?)

    @results = SearchService.search(
      query: query,
      min_price: min_price,
      max_price: max_price,
      stores: stores
    )
    @stores = Scrapers::REGISTRY.keys
    @query = query

    respond_to do |format|
      format.turbo_stream
      format.html { render 'pages/home' }
    end
  end
end
