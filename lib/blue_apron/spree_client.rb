require_relative '../blue_apron'

require 'faraday'
require 'json'
require 'hashie'

module BlueApron
  class SpreeClient
    attr_accessor :api_key
    attr_accessor :url

    ##
    # Get a list of taxonomies and taxons.
    def get_taxonomies
      response = connection.get do |request|
        request.url "/api/taxonomies"
        request.headers['X-Spree-Token'] = @api_key
        request.headers['Content-Type'] = 'application/json'
      end

      handle_response(response, 200)
    end

    ##
    # Create a Spree::Order.
    def create_order(order, options = {})
      response = connection.post do |request|
        request.url "/api/orders"        
        request.headers['X-Spree-Token'] = @api_key
        request.headers['Content-Type'] = 'application/json'
        request.body = order.to_json
      end

      handle_response(response, 201)
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

      def handle_response(response, expected_status)
        if response.status != expected_status
          raise ApiError.new(response.status, response.body) 
        else
          Hashie::Mash.new JSON.parse(response.body)
        end
      end
      
      def connection
        Faraday.new(:url => @url) do |faraday|
          faraday.request  :url_encoded             # form-encode POST params
          faraday.response :logger                  # log requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
      end

  end
end
