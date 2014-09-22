require 'spec_helper'

describe BlueApron::SpreeClient do
  let(:api_key) { 'abcdef' }
  let(:url) { 'http://nowhere.com' }

  let(:spree_client) do
    client = BlueApron::SpreeClient.new
    client.api_key = api_key
    client.url = url
    client
  end

  let(:connection) do
    Faraday.new(url: url) do |builder|
      builder.adapter(:test, stubs)
    end
  end

  let(:stubs) do
    Faraday::Adapter::Test::Stubs.new
  end

  it 'should have a version' do
    expect(BlueApron::SpreeClient::VERSION).to_not be_nil
  end

  after(:each) do
    stubs.verify_stubbed_calls
  end

  shared_examples 'a Hashie::Mash' do
    it 'should be a Hashie::Mash' do
      expect(subject).to be_a(Hashie::Mash)
    end
  end

  shared_examples "a paginated response" do
    it 'should contain pagination' do
      expect(subject[:count]).to be_a(Fixnum)
      expect(subject.current_page).to be_a(Fixnum)
      expect(subject.pages).to be_a(Fixnum)
    end
  end

  shared_examples "an order" do
    it 'should have checkout steps' do
      expect(subject.checkout_steps.size).to_not eq(0)
    end

    it 'should have a number' do
      expect(subject.number).to match(/^R/)
    end

    it 'should have a order token' do
      expect(subject.token).to_not be_nil
    end
  end

  describe '.initialize' do
    subject { BlueApron::SpreeClient.new(api_key: 'foo', url: 'bar') }

    it 'should have api_key' do
      expect(subject.api_key).to eq('foo')
    end

    it 'should have url' do
      expect(subject.url).to eq('bar')
    end
  end

  describe '#connection' do
    it 'should not be nil' do
      expect(spree_client.send(:connection)).to_not be_nil
    end
  end

  describe '#get_country' do
    let(:id) { 101 }

    subject { spree_client.get_country(id) }

    context 'when response is 200' do
      before(:each) do
        stubs.get("/api/countries/#{id}") do |env|
          validate_authenticated_request(env)
          [200, {}, read_fixture_file('get_api_country.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#apply_coupon_code' do
    let(:order_number) { 'R1234' }
    let(:coupon_code) { "FRED" }

    subject { spree_client.apply_coupon_code(order_number, coupon_code) }

    context 'when response is 200' do
      before(:each) do
        stubs.put("/api/orders/#{order_number}/apply_coupon_code") do |env|
          validate_authenticated_request(env)
          [200, {}, read_fixture_file('put_api_orders_apply_coupon_code.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#add_line_item' do
    let(:order_number) { 'R1234' }
    let(:line_item) do
      {
        line_item: {
          variant_id: 1,
          quantity: 1
        }
      }
    end

    subject { spree_client.add_line_item(order_number, line_item) }

    context 'when response is 201' do
      before(:each) do
        stubs.post("/api/orders/#{order_number}/line_items") do |env|
          expect(env[:body]).to eq(line_item.to_json)
          validate_json_request(env)
          [201, {'Content-Type' => 'application/json'}, read_fixture_file('post_api_orders_line_items.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#add_blue_apron_gift' do
    let(:order_number) { 'R1234' }
    let(:line_item_id) { 123 }
    let(:blue_apron_gift) do
      {
        blue_apron_gift: {
          sender_first_name: "Fred",
          sender_last_name: "McSun"
        }
      }
    end

    subject { spree_client.add_blue_apron_gift(order_number, line_item_id, blue_apron_gift) }

    context 'when response is 201' do
      before(:each) do
        stubs.post("/api/orders/#{order_number}/line_items/#{line_item_id}/blue_apron_gifts") do |env|
          expect(env[:body]).to eq(blue_apron_gift.to_json)
          validate_json_request(env)
          [201, {'Content-Type' => 'application/json'}, read_fixture_file('post_api_orders_line_items_blue_apron_gifts.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#update_line_item' do
    let(:order_number) { 'R1234' }
    let(:line_item_id) { 1 }
    let(:quantity) { 99 }

    subject { spree_client.update_line_item(order_number, line_item_id, quantity) }

    context 'when response is 200' do
      before(:each) do
        stubs.put("/api/orders/#{order_number}/line_items/#{line_item_id}") do |env|
          expect(env[:body]).to eq({line_item: {quantity: quantity}}.to_json)
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('put_api_orders_line_items.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#delete_line_item' do
    let(:order_number) { 'R1234' }
    let(:line_item_id) { 1 }

    subject { spree_client.delete_line_item(order_number, line_item_id) }

    context 'when response is 204' do
      before(:each) do
        stubs.delete("/api/orders/#{order_number}/line_items/#{line_item_id}") do |env|
          validate_json_request(env)
          [204, {'Content-Type' => 'application/json'}, ""]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it 'should return true' do
        expect(subject).to be_truthy
      end
    end
  end

  describe '#get_current_for_order' do
    let(:user_id) { 1234 }

    subject { spree_client.get_current_order_for(user_id) }

    context 'when response is 200' do
      before(:each) do
        stubs.get("/api/orders/current_for/#{user_id}") do |env|
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_order.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#get_order' do
    let(:order_number) { 'R1234' }
    subject { spree_client.get_order(order_number) }

    context 'when response is 200' do
      before(:each) do
        stubs.get("/api/orders/#{order_number}") do |env|
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_order.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#get_orders' do
    let(:params) { {} }

    subject { spree_client.get_orders(params) }

    context 'when response is 200' do
      before(:each) do
        stubs.get("/api/orders") do |env|
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_orders.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#get_orders_for' do
    let(:params) { {} }

    subject { spree_client.get_orders_for(1) }

    context 'when response is 200' do
      before(:each) do
        stubs.get("/api/orders") do |env|
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_orders.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#update_order' do
    let(:order_number) { 'R1234' }
    let(:order) do
      {
        order: {
          email: 'cs@cs.com'
        }
      }
    end

    subject { spree_client.update_order(order_number, order) }

    context 'when response is 200' do
      before(:each) do
        stubs.put("/api/orders/#{order_number}") do |env|
          validate_json_request(env)
          expect(env[:body]).to eq(order.to_json)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_order.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
      it_behaves_like "an order"
    end
  end

  [:next, :advance].each do |method|
    describe "#{method}" do
      let(:id) { 'R1234' }

      subject { spree_client.send(method, id) }

      context 'when response is 200' do
        before(:each) do
          stubs.put("/api/checkouts/#{id}/#{method}") do |env|
            validate_json_request(env)
            [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_order.json')]
          end
          expect(spree_client).to receive(:connection).and_return(connection)
        end

        it_behaves_like "a Hashie::Mash"
        it_behaves_like "an order"
      end
    end
  end

  describe '#empty_order' do
    let(:id) { 'R1234' }
    subject { spree_client.empty_order(id) }

    context 'when response is 200' do
      before(:each) do
        stubs.put("/api/orders/#{id}/empty") do |env|
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, ""]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it 'should return true' do
        expect(subject).to be_truthy
      end
    end
  end

  describe '#get_product' do
    let(:id) { 1 }
    subject { spree_client.get_product(id) }

    context 'when response is 200' do
      before(:each) do
        stubs.get("/api/products/#{id}") do |env|
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_product.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"
    end
  end

  describe '#get_products' do
    let(:params) { {} }

    subject { spree_client.get_products(params) }

    context 'when response is 200' do
      before(:each) do
        stubs.get('/api/products') do |env|
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_products.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"

      it_behaves_like "a paginated response"

      it "should contain products" do
        expect(subject.products).to be_a(Array)
      end
    end
  end

  describe '#get_taxons_by_slug' do
    let(:permalink) { 'brand/ruby' }

    before do
      expect(spree_client).to receive(:get_taxonomies).and_return(Hashie::Mash.new(JSON.parse(read_fixture_file('get_api_taxonomies.json'))))
    end

    subject { spree_client.get_taxons_by_permalink(permalink) }

    it 'should return a taxon' do
      expect(subject.size).to eq(1)
    end

    it 'should return taxon 8' do
      expect(subject.first.id).to eq(8)
    end
  end

  describe '#get_taxononies' do
    subject { spree_client.get_taxonomies }

    context 'when response is not 200' do
      before(:each) do
        stubs.get('/api/taxonomies') do |env|
          [500, {}, "ERROR"]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it 'should raise error' do
        expect {
          subject
        }.to raise_error(BlueApron::SpreeClient::ApiError)
      end
    end

    context 'when response is 200' do
      before(:each) do
        stubs.get('/api/taxonomies') do |env|
          validate_json_request(env)
          [200, {'Content-Type' => 'application/json'}, read_fixture_file('get_api_taxonomies.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it_behaves_like "a Hashie::Mash"

      it_behaves_like "a paginated response"

      it 'should contain taxonomies' do
        expect(subject.taxonomies).to be_a(Array)
      end

      it 'should contain taxons in taxonomies' do
        taxonomies = subject.taxonomies
        expect(taxonomies.first.name).to eq("Brand")
        expect(taxonomies.first.root.taxons.first.name).to eq("Ruby")
      end
    end
  end

  describe '#create_order' do
    let(:order) do
      {
        order: {
          email: 'spree@example.com'
        }
      }
    end

    context 'when order params not provided' do
      before do
        stubs.post('/api/orders') do |env|
          expect(env[:body]).to be_empty
          expect(env[:request_headers]['Content-Type']).to be_nil
          expect(env[:request_headers]['X-Spree-Token']).to eq(api_key)
          [201, {'Content-Type' => 'application/json'}, read_fixture_file('post_api_orders.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      subject { spree_client.create_order }

      it_behaves_like "a Hashie::Mash"
      it_behaves_like "an order"

      it 'should have an id' do
        expect(subject.id).to eq(30)
      end
    end

    context 'when order params provided' do
      before do
        stubs.post('/api/orders') do |env|
          expect(env[:body]).to eq(order.to_json)
          validate_json_request(env)
          [201, {'Content-Type' => 'application/json'}, read_fixture_file('post_api_orders.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      subject { spree_client.create_order(order: order) }

      it_behaves_like "a Hashie::Mash"
      it_behaves_like "an order"

      it 'should have an id' do
        expect(subject.id).to eq(30)
      end
    end
  end

  private

    def with_faraday_stub
      connection = Faraday.new do |builder|
        builder.adapter :test do |stubs|
          yield stub
          @stubs = stubs
        end
      end
      expect(spree_client).to receive(:connection).and_return(connection)
    end

    def validate_json_request(env)
      expect(env[:request_headers]['Accept']).to eq('application/json')
      expect(env[:request_headers]['Content-Type']).to eq('application/json')
      validate_authenticated_request(env)
    end

    def validate_authenticated_request(env)
      expect(env[:request_headers]['X-Spree-Token']).to eq(api_key)
    end

    def read_fixture_file(file_name)
      content = ""
      File.open("#{File.dirname(__FILE__)}/../fixtures/#{file_name}", "r") do |f|
        f.each_line do |line|
          content += line
        end
      end
      content
    end
end
