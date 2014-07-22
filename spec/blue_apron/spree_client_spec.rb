require 'spec_helper'

describe BlueApron::SpreeClient, :vcr do
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
      { email: 'spree@example.com' }
    end

    before do
      stubs.post('/api/orders') { [201, {'Content-Type' => 'text/html'}, 'hello'] }
      expect(spree_client).to receive(:connection).and_return(connection)
    end

    subject { spree_client.create_order(order) }

    it 'should do something' do
      subject
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
end
