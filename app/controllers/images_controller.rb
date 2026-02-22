# frozen_string_literal: true

require 'net/http'

class ImagesController < ApplicationController
  ALLOWED_HOSTS = %w[
    www.jumia.com.gh
    gh.jumia.is
    pictures-ghana.jijistatic.net
    jiji.com.gh
    telefonika.com
    compughana.com
    www.compughana.com
    cdn.shopify.com
    images.jiji.com.gh
    assets.jijistatic.net
  ].freeze

  def show
    url = params[:url].to_s
    return head(:bad_request) if url.empty?

    uri = URI.parse(url)
    return head(:bad_request) unless %w[http https].include?(uri.scheme)
    return head(:forbidden) unless ALLOWED_HOSTS.include?(uri.host)

    response = Net::HTTP.get_response(uri)
    return head(:not_found) unless response.is_a?(Net::HTTPSuccess)

    content_type = response['Content-Type'] || 'image/jpeg'
    headers['Cache-Control'] = 'public, max-age=86400'
    send_data response.body, type: content_type, disposition: 'inline'
  rescue StandardError
    head(:bad_request)
  end
end
