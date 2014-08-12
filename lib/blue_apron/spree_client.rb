require_relative '../blue_apron'

require 'faraday'
require 'json'
require 'hashie'

module BlueApron
  class SpreeClient
    attr_accessor :api_key
    attr_accessor :url
    attr_accessor :logger

    def get_countries
      get "/api/countries"
    end

    def get_country(id)
      get "/api/countries/#{id}"
    end

    def get_united_states
      get_country(49)
    end

    def initialize(options = {})
      @api_key = options[:api_key]
      @url = options[:url]
      @logger = options[:logger]
    end

    def next(order_id)
      response = connection.put do |request|
        request.url "/api/checkouts/#{order_id}/next"
        setup_authenticated_json_request(request)
      end
      handle_response(response)
    end

    def advance(order_id)
      response = connection.put do |request|
        request.url "/api/checkouts/#{order_id}/advance"
        setup_authenticated_json_request(request)
      end
      handle_response(response)
    end

    def update_checkout(order_id, payload)
      response = connection.put do |request|
        request.url "/api/checkouts/#{order_id}"
        request.body = payload.to_json
        setup_authenticated_json_request(request)
      end
      handle_response(response)
    end

    def add_line_item(order_id, line_item, options = {})
      response = connection.post do |request|
        request.url "/api/orders/#{order_id}/line_items"
        request.body = line_item.to_json
        setup_authenticated_json_request(request, options)
      end 

      handle_response(response)
    end

    def add_blue_apron_gift(order_id, line_item_id, blue_apron_gift)
      response = connection.post do |request|
        request.url "/api/orders/#{order_id}/line_items/#{line_item_id}/blue_apron_gifts"
        request.body = blue_apron_gift.to_json
        setup_authenticated_json_request(request)
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

    def apply_coupon_code(id, coupon_code)
      response = connection.put do |request|
        request.url "/api/orders/#{id}/apply_coupon_code"
        request.params = {coupon_code: coupon_code}
        setup_authenticated_request(request)
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
      get "/api/orders/#{id}", options
    end

    def get_current_order_for(user_id)
      get "/api/orders/current_for/#{user_id}"
    end

    def get_orders(options = {})
      response = connection.get do |request|
        request.url "/api/orders"
        request.params = options[:params] if options[:params]
        setup_authenticated_json_request(request)
      end

      handle_response(response)
    end

    def get_product(id)
      get "/api/products/#{id}"
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
      get "/api/taxonomies"
    end

    ##
    # Create a Spree::Order.
    def create_order(options = {})
      response = connection.post do |request|
        request.url "/api/orders"
        if options[:order]
          request.body = options[:order].to_json if options[:order]
          setup_authenticated_json_request(request)
        else
          setup_authenticated_request(request)
        end
        request.params = options[:params] if options[:params]
      end

      handle_response(response)
    end

    class ApiError < StandardError
      attr_reader :status
      attr_reader :body

      def initialize(status, body)
        @status = status
        @body = body
        
        def errors
          if @status == 422
            Hashie::Mash.new JSON.parse(@body)
          else
            nil
          end
        end
      end
    end

    class ApiNotFoundError < ApiError
    end

    private

      def get(url, options = {})
        response = connection.get do |request|
          request.url url
          setup_authenticated_json_request(request, options)
        end
        handle_response(response)
      end

      def setup_authenticated_request(request, options = {})
        if options[:order_token]
          request.headers['X-Spree-Order-Token'] = options[:order_token]
        else
          request.headers['X-Spree-Token'] = @api_key
        end
      end

      def setup_authenticated_json_request(request, options = {})
        setup_authenticated_request(request, options)

        request.headers['Content-Type'] = 'application/json'
        request.headers['Accept'] = 'application/json'
      end

      def handle_response(response)
        raise ApiNotFoundError.new(404, response.body) if response.status == 404
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
          faraday.request  :url_encoded
          faraday.adapter  Faraday.default_adapter
          faraday.use      Faraday::Response::Logger, @logger
        end
      end
  end
end
