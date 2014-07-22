require_relative '../blue_apron'

require 'faraday'
require 'json'
require 'hashie'

module BlueApron
  class SpreeClient
    attr_accessor :api_key
    attr_accessor :url

    def create_order(order, options = {})
      response = connection.post do |request|
        request.url "/api/orders"        
        request.headers['X-Spree-Token'] = @api_key
        request.headers['Content-Type'] = 'application/json'
        request.body = order.to_json
      end

      if response.status != 201
        raise ApiError.new(response.status, response.body) 
      end
      Hashie::Mash.new JSON.parse(response.body)
    end

    class ApiError < StandardError
      attr_reader :status
      attr_reader :body

      def initialize(status, body)
        @status = status
        @body = body
      end
    end

    private
      
      def connection
        Faraday.new(:url => @url) do |faraday|
          faraday.request  :url_encoded             # form-encode POST params
          faraday.response :logger                  # log requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
      end

  end
end
