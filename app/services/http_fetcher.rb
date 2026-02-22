# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'zlib'
require 'stringio'

class HttpFetcher
  DEFAULT_HEADERS = {
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language' => 'en-US,en;q=0.9',
    'Accept-Encoding' => 'gzip'
  }.freeze

  def self.get(url, headers: {}, timeout: 12, max_redirects: 3)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = timeout
    http.read_timeout = timeout

    request = Net::HTTP::Get.new(uri.request_uri)
    (DEFAULT_HEADERS.merge(headers)).each { |k, v| request[k] = v }

    response = http.request(request)

    if response.is_a?(Net::HTTPRedirection) && max_redirects.positive?
      location = response['location']
      return response if location.to_s.empty?

      return get(location, headers: headers, timeout: timeout, max_redirects: max_redirects - 1)
    end

    response_body = inflate(response)
    response.define_singleton_method(:body) { response_body }
    response
  rescue StandardError
    nil
  end

  def self.inflate(response)
    return '' unless response
    return response.body unless response['content-encoding'] == 'gzip'

    gz = Zlib::GzipReader.new(StringIO.new(response.body))
    gz.read
  rescue StandardError
    response.body.to_s
  end
end
