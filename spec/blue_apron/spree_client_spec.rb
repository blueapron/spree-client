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

  describe '#connection' do
    it 'should not be nil' do
      expect(spree_client.send(:connection)).to_not be_nil
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

    before do
      stubs.post('/api/orders') do |env|
        expect(env[:body]).to eq(order.to_json)
        expect(env[:request_headers]['Content-Type']).to eq('application/json')
        expect(env[:request_headers]['X-Spree-Token']).to eq(api_key)
        [201, {'Content-Type' => 'text/html'}, read_fixture_file('post_api_orders.json')] 
      end
      expect(spree_client).to receive(:connection).and_return(connection)
    end

    subject { spree_client.create_order(order) }

    it 'should not be nil' do
      expect(subject).to_not be_nil
    end

    it 'should have an id' do
      expect(subject.id).to eq(30)
    end

    it 'should have checkout steps' do
      expect(subject.checkout_steps).to eq(["address", "delivery", "complete"])
    end

    after do
      stubs.verify_stubbed_calls
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
