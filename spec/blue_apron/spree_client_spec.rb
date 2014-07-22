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
          expect(env[:request_headers]['Content-Type']).to eq('application/json')
          expect(env[:request_headers]['X-Spree-Token']).to eq(api_key)
          [200, {'Content-Type' => 'text/html'}, read_fixture_file('get_api_taxonomies.json')]
        end
        expect(spree_client).to receive(:connection).and_return(connection)
      end

      it 'should not be a Hashie::Mash' do
        expect(subject).to be_a(Hashie::Mash)
      end

      it 'should contain pagination' do
        expect(subject[:count]).to eq(2)          # Known issue with .count and count attribute conflicting.
        expect(subject.current_page).to eq(1)
        expect(subject.pages).to eq(1)
        
      end

      it 'should contain taxonomies' do
        expect(subject.taxonomies.size).to eq(2)
      end

      it 'should contain taxons in taxonomies' do
        taxonomies = subject.taxonomies
        expect(taxonomies.first.name).to eq("Brand")
        expect(taxonomies.first.root.taxons.first.name).to eq("Ruby")
      end

      after(:each) do
        stubs.verify_stubbed_calls
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

    it 'should not be a Hashie::Mash' do
      expect(subject).to be_a(Hashie::Mash)
    end

    it 'should have an id' do
      expect(subject.id).to eq(30)
    end

    it 'should have checkout steps' do
      expect(subject.checkout_steps).to eq(["address", "delivery", "complete"])
    end

    after(:each) do
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
