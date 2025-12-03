# frozen_string_literal: true

require 'rails_helper'

# NOTE: To run these tests, add 'webmock' gem to your Gemfile:
#   gem 'webmock', group: :test
# Then run: bundle install

RSpec.describe WeatherForecastApiFetcher do
  let(:city) { 'Boston' }
  let(:start_date) { Date.today }
  let(:end_date) { Date.today + 2.days }
  let(:fetcher) { described_class.new(city, start_date, end_date) }

  describe '#fetch' do
    context 'when API returns successful response' do
      let(:api_response) do
        {
          'timelines' => {
            'daily' => [
              {
                'time' => Date.today.to_s,
                'values' => {
                  'temperatureMax' => 75.5,
                  'temperatureMin' => 55.2,
                  'temperatureAvg' => 65.3,
                  'temperatureApparentMax' => 73.0,
                  'temperatureApparentMin' => 53.0,
                  'temperatureApparentAvg' => 63.0,
                  'weatherCodeMax' => 1000,
                  'precipitationProbabilityMax' => 10.0,
                  'uvIndexMax' => 5
                }
              },
              {
                'time' => (Date.today + 1.day).to_s,
                'values' => {
                  'temperatureMax' => 68.8,
                  'temperatureMin' => 48.3,
                  'temperatureAvg' => 58.5,
                  'temperatureApparentMax' => 66.0,
                  'temperatureApparentMin' => 46.0,
                  'temperatureApparentAvg' => 56.0,
                  'weatherCodeMax' => 4001,
                  'precipitationProbabilityMax' => 75.5,
                  'uvIndexMax' => 3
                }
              },
              {
                'time' => (Date.today + 2.days).to_s,
                'values' => {
                  'temperatureMax' => 80.2,
                  'temperatureMin' => 60.1,
                  'temperatureAvg' => 70.1,
                  'temperatureApparentMax' => 78.0,
                  'temperatureApparentMin' => 58.0,
                  'temperatureApparentAvg' => 68.0,
                  'weatherCodeMax' => 1100,
                  'precipitationProbabilityMax' => 5.0,
                  'uvIndexMax' => 7
                }
              },
              {
                'time' => (Date.today + 3.days).to_s,
                'values' => {
                  'temperatureMax' => 72.0,
                  'temperatureMin' => 52.0,
                  'temperatureAvg' => 62.0,
                  'temperatureApparentMax' => 70.0,
                  'temperatureApparentMin' => 50.0,
                  'temperatureApparentAvg' => 60.0,
                  'weatherCodeMax' => 1001,
                  'precipitationProbabilityMax' => 20.0,
                  'uvIndexMax' => 4
                }
              },
              {
                'time' => (Date.today + 4.days).to_s,
                'values' => {
                  'temperatureMax' => 77.0,
                  'temperatureMin' => 57.0,
                  'temperatureAvg' => 67.0,
                  'temperatureApparentMax' => 75.0,
                  'temperatureApparentMin' => 55.0,
                  'temperatureApparentAvg' => 65.0,
                  'weatherCodeMax' => 1100,
                  'precipitationProbabilityMax' => 15.0,
                  'uvIndexMax' => 6
                }
              }
            ]
          }
        }
      end

      before do
        # Stub the HTTParty.get call
        allow(HTTParty).to receive(:get).and_return(
          double(
            success?: true,
            parsed_response: api_response
          )
        )
      end

      it 'returns array of forecast hashes' do
        result = fetcher.fetch
        expect(result).to be_an(Array)
        expect(result.size).to eq(3)
      end

      it 'filters forecasts to requested date range' do
        result = fetcher.fetch
        dates = result.map { |f| f[:date] }

        # Should only include dates within the requested range (today through today+2)
        expect(dates).to contain_exactly(Date.today, Date.today + 1.day, Date.today + 2.days)
        # Should NOT include dates outside the range
        expect(dates).not_to include(Date.today + 3.days)
        expect(dates).not_to include(Date.today + 4.days)
      end

      it 'includes all required fields' do
        result = fetcher.fetch
        first_forecast = result.first

        expect(first_forecast).to include(
          :city,
          :date,
          :temperature_max,
          :temperature_min,
          :temperature_avg,
          :temperature_apparent_max,
          :temperature_apparent_min,
          :temperature_apparent_avg,
          :conditions,
          :precipitation_probability,
          :uv_index_max
        )
      end

      it 'rounds temperature values to 1 decimal place' do
        result = fetcher.fetch
        first_forecast = result.first

        expect(first_forecast[:temperature_max]).to eq(75.5)
        expect(first_forecast[:temperature_min]).to eq(55.2)
        expect(first_forecast[:temperature_avg]).to eq(65.3)
      end

      it 'maps weather codes to conditions' do
        result = fetcher.fetch

        # Weather code 1000 should map to "Clear, Sunny"
        expect(result[0][:conditions]).to be_a(String)
        expect(result[0][:conditions]).not_to eq('Unknown')
      end

      it 'sets city for each forecast' do
        result = fetcher.fetch
        result.each do |forecast|
          expect(forecast[:city]).to eq(city)
        end
      end
    end

    context 'when API returns error response' do
      before do
        allow(HTTParty).to receive(:get).and_return(
          double(success?: false, code: 401, body: 'Unauthorized')
        )
      end

      it 'raises WeatherAPIError' do
        expect { fetcher.fetch }.to raise_error(
          WeatherForecastApiFetcher::WeatherAPIError,
          /API returned 401/
        )
      end
    end

    context 'when API response has invalid structure' do
      before do
        allow(HTTParty).to receive(:get).and_return(
          double(
            success?: true,
            parsed_response: { 'invalid' => 'structure' }
          )
        )
      end

      it 'raises WeatherAPIError' do
        expect { fetcher.fetch }.to raise_error(
          WeatherForecastApiFetcher::WeatherAPIError,
          /Invalid API response structure/
        )
      end
    end

    context 'when network error occurs' do
      before do
        allow(HTTParty).to receive(:get).and_raise(SocketError, 'Connection refused')
      end

      it 'raises WeatherAPIError' do
        expect { fetcher.fetch }.to raise_error(
          WeatherForecastApiFetcher::WeatherAPIError,
          /Failed to fetch weather data: Connection refused/
        )
      end
    end

    context 'when timeout occurs' do
      before do
        allow(HTTParty).to receive(:get).and_raise(Timeout::Error)
      end

      it 'raises WeatherAPIError' do
        expect { fetcher.fetch }.to raise_error(
          WeatherForecastApiFetcher::WeatherAPIError,
          /Failed to fetch weather data/
        )
      end
    end
  end

  describe '#map_weather_code' do
    it 'returns "Unknown" for nil code' do
      mapper = fetcher.send(:map_weather_code, nil)
      expect(mapper).to eq('Unknown')
    end

    it 'returns fallback for unknown codes' do
      mapper = fetcher.send(:map_weather_code, 99999)
      expect(mapper).to eq('Unknown')
    end
  end

  describe 'API configuration' do
    before do
      # Mock the API key for testing
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('WEATHER_API_KEY').and_return('test_api_key')
    end

    it 'includes required query parameters' do
      allow(HTTParty).to receive(:get) do |url, options|
        query = options[:query]

        expect(query[:location]).to eq(city)
        expect(query[:timesteps]).to eq('1d')
        expect(query[:units]).to eq('imperial')
        expect(query[:apikey]).to eq('test_api_key')

        double(success?: false, code: 500, body: '')
      end

      begin
        fetcher.fetch
      rescue WeatherForecastApiFetcher::WeatherAPIError
        # Expected to raise error, we just want to verify HTTParty.get was called correctly
      end
    end

    it 'sets 10 second timeout' do
      allow(HTTParty).to receive(:get) do |url, options|
        expect(options[:timeout]).to eq(10)
        double(success?: false, code: 500, body: '')
      end

      begin
        fetcher.fetch
      rescue WeatherForecastApiFetcher::WeatherAPIError
        # Expected
      end
    end
  end
end
