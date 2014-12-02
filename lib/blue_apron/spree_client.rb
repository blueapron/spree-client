require_relative '../blue_apron'

require 'sanitize'
require 'faraday'
require 'json'
require 'hashie'

module BlueApron
  class SpreeClient
    attr_accessor :api_key
    attr_accessor :url
    attr_accessor :logger

    def initialize(options = {})
      @api_key = options[:api_key]
      @url = options[:url]
      @logger = options[:logger]
      @timeout = options[:timeout]
    end

    def get_variant_stock(variant_id, stock_location_id = 1)
      get "/api/stock_locations/#{stock_location_id}/stock_items", params: {'q[variant_id_eq]' => variant_id}
    end

    def get_countries
      get "/api/countries"
    end

    def get_country(id)
      get "/api/countries/#{id}"
    end

    def get_united_states
      get_country(49)
    end

    def get_promotion(id)
      get "/api/promotions/#{id}"
    end

    def next(order_id)
      put "/api/checkouts/#{order_id}/next"
    end

    def advance(order_id)
      put "/api/checkouts/#{order_id}/advance"
    end

    def update_checkout(order_id, payload)
      put "/api/checkouts/#{order_id}", body: payload.to_json
    end

    def add_line_item(order_id, line_item, options = {})
      options[:body] = line_item.to_json
      post "/api/orders/#{order_id}/line_items", options
    end

    def add_blue_apron_gift(order_id, line_item_id, blue_apron_gift)
      post "/api/orders/#{order_id}/line_items/#{line_item_id}/blue_apron_gifts", body: blue_apron_gift.to_json
    end

    def add_blue_apron_recurring_preference(order_id, line_item_id)
      post "/api/orders/#{order_id}/line_items/#{line_item_id}/blue_apron_recurring_preferences"
    end

    def update_line_item(order_id, line_item_id, quantity, options = {})
      options[:body] = {line_item: {quantity: quantity}}.to_json
      put "/api/orders/#{order_id}/line_items/#{line_item_id}", options
    end

    def delete_line_item(order_id, line_item_id, options = {})
      response = connection.delete do |request|
        request.url "/api/orders/#{order_id}/line_items/#{line_item_id}"
        setup_authenticated_json_request(request, options)
      end
      handle_response(response)
    end

    def apply_coupon_code(id, coupon_code)
      put "/api/orders/#{id}/apply_coupon_code", params: {coupon_code: coupon_code}
    end

    def patch_order_key_value(id, key, value, options = {})
      options[:body] = { :order => {key => value} }.to_json
      patch "/api/orders/#{id}", options
    end

    def patch_order(id, order, options = {})
      options[:body] = order.to_json
      patch "/api/orders/#{id}", options
    end

    def update_order(id, order, options = {})
      options[:body] = order.to_json
      put "/api/orders/#{id}", options
    end

    def empty_order(id, options = {})
      put "/api/orders/#{id}/empty", options
    end

    def get_order(id, options = {})
      get "/api/orders/#{id}", options
    end

    def get_shipment(id, options = {})
      get "/api/shipments/#{id}", options
    end

    def get_current_order_for(user_id)
      get "/api/orders/current_for/#{user_id}"
    end

    def get_orders(options = {})
      get "/api/orders", options
    end

    def get_orders_for(user_id, state = ['confirm', 'complete'], page = 1)
      get_orders({params: {'q[blue_apron_user_id_eq]' => user_id, 'q[state_in]' => state, 'q[s]' => 'completed_at desc', page: page}})
    end

    def get_product(id)
      product = get "/api/products/#{id}"
      sanitize_product!(product)
      product
    end

    def get_products(options = {})
      response = get "/api/products", options
      response.products.each do |product|
        sanitize_product!(product)
      end
      response
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
    def get_taxonomies(options = {})
      get "/api/taxonomies", options
    end

    ##
    # Get a specifix taxon.
    def get_taxon(taxonomy_id, taxon_id)
      get "/api/taxonomies/#{taxonomy_id}/taxons/#{taxon_id}"
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
          request.params = options[:params] if options[:params]
          setup_timeouts(request)
          setup_authenticated_json_request(request, options)
        end
        handle_response(response)
      end

      def post(url, options = {})
        response = connection.post do |request|
          request.url url
          request.body = options[:body] if options[:body]
          setup_timeouts(request)
          setup_authenticated_json_request(request)
        end
        handle_response(response)
      end

      def patch(url, options = {})
        perform_http_action :patch, url, options
      end

      def put(url, options = {})
        perform_http_action :put, url, options
      end

      def perform_http_action(verb, url, options = {})
        response = connection.send(verb) do |request|
          request.url url
          request.body = options[:body] if options[:body]
          request.params = options[:params] if options[:params]
          setup_timeouts(request)
          setup_authenticated_json_request(request)
        end
        handle_response(response)
      end

      def setup_timeouts(request)
        #request.options.timeout = 10
        request.options.open_timeout = timeout
      end

      def timeout
        @timeout || 4
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
          if @logger
            faraday.use      Faraday::Response::Logger, @logger
          end
        end
      end

      ##
      # Clean up HTML in known sections where HTML markup is being inserted in Spree.
      def sanitize_product!(product)
        product.cms_text = sanitize_html(product.cms_text)
        product.description = sanitize_html(product.description)
        product.product_properties.each do |pp|
          pp.value = sanitize_html(pp.value)
        end unless product.product_properties.nil?
      end

      def sanitize_html(s)
        Sanitize.fragment(s, Sanitize::Config::RELAXED)
      end
  end
end
