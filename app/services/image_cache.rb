# frozen_string_literal: true

class ImageCache
  CACHE_TTL = 6.hours

  @mutex = Mutex.new
  @in_flight = {}

  class << self
    def get(key)
      Rails.cache.read(key)
    end

    def fetch_async(key, &block)
      cached = Rails.cache.read(key)
      return cached if cached.present?

      @mutex.synchronize do
        return if @in_flight[key]
        @in_flight[key] = true
      end

      Thread.new do
        begin
          value = block.call
          Rails.cache.write(key, value.to_s, expires_in: CACHE_TTL) if value
        ensure
          @mutex.synchronize { @in_flight.delete(key) }
        end
      end

      nil
    end
  end
end
