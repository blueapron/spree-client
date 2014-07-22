require_relative '../blue_apron'

require 'faraday'
require 'json'
require 'hashie'

module BlueApron
  class SpreeClient
    attr_accessor :api_key
    attr_accessor :url

    def add_line_item(order_id, line_item, options = {})
      response = connection.post do |request|
        request.url "/api/orders/#{order_id}/line_items"
        request.body = line_item.to_json
        setup_authenticated_json_request(request, options)
      end 

      handle_response(response)
    end

    def update_line_item(order_id, line_item_id, quantity, options = {})
      response = connection.put do |request|
        request.url "/api/orders/#{order_id}/line_items/#{line_item_id}"
        request.body = {line_item: {quantity: quantity}}.to_json
        setup_authenticated_json_request(request, options)
      end

      handle_response(response)
    end

    def delete_line_item(order_id, line_item_id, options = {})
      response = connection.delete do |request|
        request.url "/api/orders/#{order_id}/line_items/#{line_item_id}"
        setup_authenticated_json_request(request, options)
      end
      handle_response(response)
    end

    def update_order(id, order, options = {})
      response = connection.put do |request|
        request.url "/api/orders/#{id}"
        request.body = order.to_json
        setup_authenticated_json_request(request, options)
      end

      handle_response(response)
    end

    def empty_order(id, options = {}) 
      response = connection.put do |request|
        request.url "/api/orders/#{id}/empty"
        setup_authenticated_json_request(request, options)
      end

      handle_response(response)
    end

    def get_order(id, options = {})
      response = connection.get do |request|
        request.url "/api/orders/#{id}"
        setup_authenticated_json_request(request, options)
      end

      handle_response(response)
    end

    def get_product(id)
      response = connection.get do |request|
        request.url "/api/products/#{id}"
        setup_authenticated_json_request(request)
      end

      handle_response(response)
    end

    def get_products(options = {})
      response = connection.get do |request|
        request.url "/api/products"
        request.params = options[:params] if options[:params]
        setup_authenticated_json_request(request)
      end
 
      handle_response(response)
    end

    ##
    # Return a taxon based on the permalink
    def get_taxons_by_permalink(permalink)
      taxonomies = get_taxonomies.taxonomies
      taxons = []
      taxonomies.each do |taxonomy|
        taxons += taxonomy.root.taxons.select { |taxon| taxon.permalink == permalink }
      end
      taxons
    end

    ##
    # Get a list of taxonomies and taxons.
    def get_taxonomies
      response = connection.get do |request|
        request.url "/api/taxonomies"
        setup_authenticated_json_request(request)
      end

      handle_response(response)
    end

    ##
    # Create a Spree::Order.
    def create_order(options = {})
      response = connection.post do |request|
        request.url "/api/orders"        
        request.body = options[:order].to_json if options[:order]
        request.params = options[:params] if options[:params]
        setup_authenticated_json_request(request)
      end

      handle_response(response)
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

      def setup_authenticated_json_request(request, options = {})
        if options[:order_token]
          request.headers['X-Spree-Order-Token'] = options[:order_token]
        else
          request.headers['X-Spree-Token'] = @api_key
        end
        request.headers['Content-Type'] = 'application/json'
        request.headers['Accept'] = 'application/json'
      end

      def handle_response(response)
        raise ApiError.new(response.status, response.body) unless [200, 201, 204].include?(response.status)

        if response.status == 204
          true
        elsif response.body && !response.body.empty?
          Hashie::Mash.new JSON.parse(response.body)
        else
          true 
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
