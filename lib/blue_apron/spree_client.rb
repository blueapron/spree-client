require_relative '../blue_apron'
require 'faraday'

module BlueApron
  class SpreeClient
    attr_accessor :api_key
    attr_accessor :url

    def create_order(order, options = {})
      connection.post do |request|
        request.url "/api/orders"        
        request.headers['X-Spree-Token'] = @api_key
        request.body = order
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
