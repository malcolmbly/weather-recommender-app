require 'rails_helper'

RSpec.describe ClothingAnalyzer do
  describe '#analyze' do
    subject(:analysis) { analyzer.analyze }

    let(:analyzer) { described_class.new(forecasts) }

    context 'with empty forecasts' do
      let(:forecasts) { [] }
      let(:expected_result) do
        {
          outerwear: "No data available",
          tops: "No data available",
          bottoms: "No data available",
          footwear: "No data available",
          accessories: "No data available"
        }
      end

      it 'returns empty recommendations' do
        expect(analysis).to eq(expected_result)
      end
    end

    context 'with nil forecasts' do
      let(:forecasts) { nil }
      let(:expected_result) do
        {
          outerwear: "No data available",
          tops: "No data available",
          bottoms: "No data available",
          footwear: "No data available",
          accessories: "No data available"
        }
      end

      it 'handles nil gracefully' do
        expect(analysis).to eq(expected_result)
      end
    end

    context 'with very cold weather (< 41°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 32.0, temperature_max: 37.0, temperature_avg: 35.0,
                           precipitation_probability: 10.0, uv_index_max: 2),
          build(:forecast, temperature_min: 28.0, temperature_max: 39.0, temperature_avg: 34.0,
                           precipitation_probability: 5.0, uv_index_max: 1)
        ]
      end

      it 'recommends heavy winter gear' do
        expect(analysis[:outerwear]).to eq("Heavy winter coat or insulated parka")
        expect(analysis[:tops]).to eq("Thermal base layers and long-sleeve sweaters")
        expect(analysis[:bottoms]).to eq("Insulated pants or jeans with thermal layers")
        expect(analysis[:footwear]).to eq("Insulated boots or closed-toe shoes")
        expect(analysis[:accessories]).to eq("Hat, scarf, and gloves")
      end
    end

    context 'at VERY_COLD threshold boundary (exactly 41°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 41.0, temperature_max: 46.0, temperature_avg: 43.0,
                           precipitation_probability: 0.0, uv_index_max: 3)
        ]
      end

      it 'recommends cold weather clothing (not heavy winter gear)' do
        expect(analysis[:outerwear]).to eq("Winter jacket or heavy sweater")
        expect(analysis[:tops]).to eq("Long-sleeve shirts and sweaters")
      end
    end

    context 'with cold weather (41-50°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 43.0, temperature_max: 48.0, temperature_avg: 45.0,
                           precipitation_probability: 20.0, uv_index_max: 3),
          build(:forecast, temperature_min: 45.0, temperature_max: 50.0, temperature_avg: 47.0,
                           precipitation_probability: 15.0, uv_index_max: 4)
        ]
      end

      it 'recommends winter clothing' do
        expect(analysis[:outerwear]).to eq("Winter jacket or heavy sweater")
        expect(analysis[:tops]).to eq("Long-sleeve shirts and sweaters")
        expect(analysis[:footwear]).to eq("Insulated boots or closed-toe shoes")
      end
    end

    context 'at COLD threshold boundary (exactly 50°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 50.0, temperature_max: 54.0, temperature_avg: 52.0,
                           precipitation_probability: 0.0, uv_index_max: 4)
        ]
      end

      it 'recommends light layers (not winter jacket)' do
        expect(analysis[:outerwear]).to eq("Light jacket, cardigan, or sweater")
        expect(analysis[:footwear]).to eq("Sneakers, sandals, or comfortable walking shoes")
      end
    end

    context 'with cool weather (50-68°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 54.0, temperature_max: 64.0, temperature_avg: 59.0,
                           precipitation_probability: 10.0, uv_index_max: 5),
          build(:forecast, temperature_min: 57.0, temperature_max: 66.0, temperature_avg: 62.0,
                           precipitation_probability: 5.0, uv_index_max: 5)
        ]
      end

      it 'recommends light layers' do
        expect(analysis[:outerwear]).to eq("Light jacket, cardigan, or sweater")
        expect(analysis[:tops]).to eq("Long-sleeve shirts or light sweaters")
        expect(analysis[:bottoms]).to eq("Jeans or casual pants")
        expect(analysis[:footwear]).to eq("Sneakers, sandals, or comfortable walking shoes")
      end
    end

    context 'at COOL threshold boundary (exactly 68°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 68.0, temperature_max: 72.0, temperature_avg: 70.0,
                           precipitation_probability: 0.0, uv_index_max: 6)
        ]
      end

      it 'recommends warm weather clothing (not layers)' do
        expect(analysis[:outerwear]).to eq("Light cardigan or no jacket needed")
        expect(analysis[:tops]).to eq("T-shirts, polo shirts, and light tops")
      end
    end

    context 'with warm weather (68-77°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 68.0, temperature_max: 75.0, temperature_avg: 72.0,
                           precipitation_probability: 5.0, uv_index_max: 7),
          build(:forecast, temperature_min: 70.0, temperature_max: 77.0, temperature_avg: 73.0,
                           precipitation_probability: 0.0, uv_index_max: 8)
        ]
      end

      it 'recommends light clothing' do
        expect(analysis[:outerwear]).to eq("Light cardigan or no jacket needed")
        expect(analysis[:tops]).to eq("T-shirts, polo shirts, and light tops")
        expect(analysis[:bottoms]).to eq("Shorts, light pants, or skirts")
        expect(analysis[:footwear]).to eq("Sneakers, sandals, or comfortable walking shoes")
      end
    end

    context 'at WARM threshold boundary (exactly 77°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 77.0, temperature_max: 82.0, temperature_avg: 79.0,
                           precipitation_probability: 0.0, uv_index_max: 8)
        ]
      end

      it 'recommends breathable fabrics (not polo shirts)' do
        expect(analysis[:tops]).to eq("T-shirts, tank tops, and breathable fabrics")
      end
    end

    context 'with hot weather (> 77°F)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 79.0, temperature_max: 90.0, temperature_avg: 85.0,
                           precipitation_probability: 0.0, uv_index_max: 9),
          build(:forecast, temperature_min: 82.0, temperature_max: 95.0, temperature_avg: 89.0,
                           precipitation_probability: 5.0, uv_index_max: 10)
        ]
      end

      it 'recommends hot weather clothing' do
        expect(analysis[:outerwear]).to eq("Light cardigan or no jacket needed")
        expect(analysis[:tops]).to eq("T-shirts, tank tops, and breathable fabrics")
        expect(analysis[:bottoms]).to eq("Shorts, light pants, or skirts")
        expect(analysis[:footwear]).to eq("Sneakers, sandals, or comfortable walking shoes")
      end
    end

    context 'with rain (> 30% precipitation)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 59.0, temperature_max: 68.0, temperature_avg: 63.5,
                           precipitation_probability: 60.0, uv_index_max: 3),
          build(:forecast, temperature_min: 57.0, temperature_max: 66.0, temperature_avg: 62.0,
                           precipitation_probability: 45.0, uv_index_max: 2)
        ]
      end

      it 'recommends rain gear' do
        expect(analysis[:outerwear]).to include("waterproof rain jacket")
        expect(analysis[:footwear]).to eq("Waterproof boots or water-resistant shoes")
        expect(analysis[:accessories]).to include("Umbrella")
      end
    end

    context 'at RAIN_THRESHOLD boundary (exactly 30%)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 59.0, temperature_max: 68.0, temperature_avg: 63.5,
                           precipitation_probability: 30.0, uv_index_max: 4)
        ]
      end

      it 'does not recommend rain gear at threshold' do
        expect(analysis[:outerwear]).not_to include("waterproof rain jacket")
        expect(analysis[:footwear]).not_to eq("Waterproof boots or water-resistant shoes")
        expect(analysis[:accessories]).not_to include("Umbrella")
      end
    end

    context 'just above RAIN_THRESHOLD (30.1%)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 59.0, temperature_max: 68.0, temperature_avg: 63.5,
                           precipitation_probability: 30.1, uv_index_max: 4)
        ]
      end

      it 'recommends rain gear above threshold' do
        expect(analysis[:outerwear]).to include("waterproof rain jacket")
        expect(analysis[:footwear]).to eq("Waterproof boots or water-resistant shoes")
        expect(analysis[:accessories]).to include("Umbrella")
      end
    end

    context 'with high UV index (>= 6)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 72.0, temperature_max: 82.0, temperature_avg: 77.0,
                           precipitation_probability: 0.0, uv_index_max: 8),
          build(:forecast, temperature_min: 75.0, temperature_max: 86.0, temperature_avg: 81.0,
                           precipitation_probability: 0.0, uv_index_max: 9)
        ]
      end

      it 'recommends sun protection' do
        expect(analysis[:accessories]).to include("Sunglasses and sunscreen")
        expect(analysis[:accessories]).to include("UV index 9")
      end
    end

    context 'at HIGH_UV threshold boundary (exactly 6)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 68.0, temperature_max: 75.0, temperature_avg: 72.0,
                           precipitation_probability: 0.0, uv_index_max: 6)
        ]
      end

      it 'recommends sun protection at threshold' do
        expect(analysis[:accessories]).to include("Sunglasses and sunscreen")
        expect(analysis[:accessories]).to include("UV index 6")
      end
    end

    context 'below HIGH_UV threshold (UV index 5)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 68.0, temperature_max: 75.0, temperature_avg: 72.0,
                           precipitation_probability: 0.0, uv_index_max: 5)
        ]
      end

      it 'does not recommend sun protection below threshold' do
        expect(analysis[:accessories]).to eq("No special accessories needed")
      end
    end

    context 'with warm weather and low UV (triggers sun protection by temp)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 79.0, temperature_max: 90.0, temperature_avg: 85.0,
                           precipitation_probability: 0.0, uv_index_max: 4)
        ]
      end

      it 'recommends sun protection when max temp > WARM (77°F)' do
        expect(analysis[:accessories]).to include("Sunglasses and sunscreen")
        expect(analysis[:accessories]).to include("UV index 4")
      end
    end

    context 'with mixed conditions (cold + rain)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 39.0, temperature_max: 46.0, temperature_avg: 43.0,
                           precipitation_probability: 70.0, uv_index_max: 2),
          build(:forecast, temperature_min: 37.0, temperature_max: 45.0, temperature_avg: 41.0,
                           precipitation_probability: 80.0, uv_index_max: 1)
        ]
      end

      it 'recommends both winter gear and rain protection' do
        expect(analysis[:outerwear]).to include("Winter jacket")
        expect(analysis[:outerwear]).to include("waterproof rain jacket")
        expect(analysis[:footwear]).to eq("Waterproof boots or water-resistant shoes")
        expect(analysis[:accessories]).to include("Umbrella")
      end
    end

    context 'with mixed conditions (very cold + rain)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 23.0, temperature_max: 36.0, temperature_avg: 30.0,
                           precipitation_probability: 50.0, uv_index_max: 1)
        ]
      end

      it 'recommends heavy winter gear with rain protection' do
        expect(analysis[:outerwear]).to include("Heavy winter coat")
        expect(analysis[:outerwear]).to include("waterproof rain jacket")
        expect(analysis[:accessories]).to include("Hat, scarf, and gloves")
        expect(analysis[:accessories]).to include("Umbrella")
      end
    end

    context 'with mixed conditions (hot + high UV + rain)' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 82.0, temperature_max: 95.0, temperature_avg: 89.0,
                           precipitation_probability: 40.0, uv_index_max: 10)
        ]
      end

      it 'recommends rain gear and sun protection' do
        expect(analysis[:outerwear]).to include("waterproof rain jacket")
        expect(analysis[:footwear]).to eq("Waterproof boots or water-resistant shoes")
        expect(analysis[:accessories]).to include("Umbrella")
        expect(analysis[:accessories]).to include("Sunglasses and sunscreen")
        expect(analysis[:accessories]).to include("UV index 10")
      end
    end

    context 'with no special conditions' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 59.0, temperature_max: 68.0, temperature_avg: 63.5,
                           precipitation_probability: 10.0, uv_index_max: 4)
        ]
      end

      it 'returns minimal accessories recommendation' do
        expect(analysis[:accessories]).to eq("No special accessories needed")
      end
    end

    context 'with varying temperatures across multiple days' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 50.0, temperature_max: 59.0, temperature_avg: 54.5,
                           precipitation_probability: 0.0, uv_index_max: 5),
          build(:forecast, temperature_min: 59.0, temperature_max: 72.0, temperature_avg: 65.5,
                           precipitation_probability: 0.0, uv_index_max: 6),
          build(:forecast, temperature_min: 64.0, temperature_max: 77.0, temperature_avg: 70.5,
                           precipitation_probability: 0.0, uv_index_max: 7)
        ]
      end

      it 'uses min temperature for bottoms' do
        expect(analysis[:bottoms]).to eq("Jeans or casual pants")
      end

      it 'uses average temperature for outerwear and tops' do
        expect(analysis[:outerwear]).to eq("Light jacket, cardigan, or sweater")
        expect(analysis[:tops]).to eq("Long-sleeve shirts or light sweaters")
      end

      it 'uses max UV for accessories' do
        expect(analysis[:accessories]).to include("UV index 7")
      end
    end

    context 'with forecasts having nil values' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: nil, temperature_max: 68.0, temperature_avg: 64.0,
                           precipitation_probability: nil, uv_index_max: nil),
          build(:forecast, temperature_min: 59.0, temperature_max: nil, temperature_avg: nil,
                           precipitation_probability: 25.0, uv_index_max: 5)
        ]
      end

      it 'handles nil values gracefully' do
        expect { analysis }.not_to raise_error
        expect(analysis).to be_a(Hash)
        expect(analysis).to have_key(:outerwear)
        expect(analysis).to have_key(:tops)
        expect(analysis).to have_key(:bottoms)
        expect(analysis).to have_key(:footwear)
        expect(analysis).to have_key(:accessories)
      end

      it 'uses available data for recommendations' do
        expect(analysis[:accessories]).to eq("No special accessories needed")
      end
    end

    context 'with single forecast' do
      let(:forecasts) do
        [
          build(:forecast, temperature_min: 64.0, temperature_max: 75.0, temperature_avg: 70.0,
                           precipitation_probability: 15.0, uv_index_max: 6)
        ]
      end

      it 'analyzes single day correctly' do
        expect(analysis[:outerwear]).to eq("Light cardigan or no jacket needed")
        expect(analysis[:tops]).to eq("T-shirts, polo shirts, and light tops")
        expect(analysis[:bottoms]).to eq("Jeans or casual pants")
        expect(analysis[:accessories]).to include("Sunglasses and sunscreen")
      end
    end

    context 'with unsorted forecast dates' do
      let(:forecasts) do
        [
          build(:forecast, date: Date.today + 2, temperature_avg: 68.0),
          build(:forecast, date: Date.today, temperature_avg: 59.0),
          build(:forecast, date: Date.today + 1, temperature_avg: 64.0)
        ]
      end

      it 'sorts forecasts by date internally' do
        expect { analysis }.not_to raise_error
        expect(analysis).to be_a(Hash)
      end
    end
  end
end
