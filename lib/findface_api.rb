require 'faraday'
require 'faraday_middleware'
require 'ostruct'
require 'findface_api/version'

# Findface API
module FindfaceApi
  ENDPOINT_URI = "https://api.findface.pro/v#{API_VERSION}/".freeze

  # Configuration
  module Configuration
    attr_accessor :access_token, :proxy, :logger, :adapter
    def configure
      yield self
      true
    end
  end

  # Connection
  module Connection
    def connection
      raise 'No access token specified' if access_token.nil?
      @connection ||= begin
        conn = Faraday.new ENDPOINT_URI do |c|
          c.authorization :Token, access_token
          c.request :multipart
          c.request :json # either :json or :url_encoded
          c.response :json, content_type: /\bjson$/
          c.response :logger, logger, bodies: true unless logger.nil?
          c.response :raise_error
          c.proxy proxy unless proxy.nil?
          c.adapter adapter.nil? ? Faraday.default_adapter : adapter
        end
        conn
      end
    end
  end

  # API Entities
  module Entities
    # Bounding box
    # Represents a rectangle on a photo. Usually used as a face's bounding box.
    class BBox
      attr_accessor :x1, :x2, :y1, :y2
      def initialize(x1:, x2:, y1:, y2:)
        @x1, @x2, @y1, @y2 = x1, x2, y1, y2
      end
      def to_h
        { x1: x1, x2: x2, y1: y1, y2: y2}
      end
    end

    # Face
    # Represents a human face. Note that it might be several faces on a single photo.
    # Different photos of the same person as also considered to be different faces.
    class Face
      attr_reader :id, :timestamp, :photo, :photo_hash, :thumbnail, :bbox, :meta, :galleries
    end
  end

  module Helpers
    def symbolize(myhash)
      myhash.keys.each do |key|
        myhash[(key.to_sym rescue key) || key] = myhash.delete(key)
      end
      myhash
    end

    def request_body(keys, options, **args)
      options.reject { |key, _| !keys.include? key }
      options.merge(args)
    end

    def request_path(path, options)
      path
        .gsub(':gallery', options.fetch(:gallery, :default).to_s)
        .gsub(':meta', options.fetch(:meta, '').to_s)
    end
  end

  # API Methods
  module APIMethods
    def detect(photo)
      response = connection.post('detect/', photo: photo)
      response.body['faces'].map do |box|
        ::FindfaceApi::Entities::BBox.new(**symbolize(box))
      end
    end

    def verify(photo1, photo2, **options)
      keys = %i(bbox1 bbox2 threshold mf_selector)
      payload = request_body(keys, options, photo1: photo1, photo2: photo2)
      response = connection.post('verify/', payload)
      response.body
    end

    def identify(photo, **options)
      keys = %i(bbox threshold n mf_selector)
      payload = request_body(keys, options, photo: photo)
      path = request_path('faces/gallery/:gallery/identify/', options)
      response = connection.post(path, payload)
      response.body['results']
    end
  end

  extend Configuration
  extend Connection
  extend Helpers
  extend Entities
  extend APIMethods
end
