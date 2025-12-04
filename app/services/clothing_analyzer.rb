class ClothingAnalyzer
  # Temperature thresholds (Fahrenheit - API uses imperial units)
  # Note: Future enhancement will add metric/imperial toggle in UI
  VERY_COLD = 41.0    # Below this: heavy winter gear (5°C)
  COLD = 50.0         # Below this: cold weather clothing (10°C)
  COOL = 68.0         # Below this: light layers (20°C)
  WARM = 77.0         # Below this: warm weather clothing (25°C)
  HOT = 86.0          # Below this: hot weather clothing (30°C)

  RAIN_THRESHOLD = 30.0  # Precipitation probability %
  HIGH_UV = 6            # UV index threshold

  def initialize(forecasts)
    @forecasts = Array(forecasts).sort_by(&:date)
  end

  def analyze
    return empty_recommendations if @forecasts.empty?

    # Returns hash with 5 clothing categories
    {
      outerwear: analyze_outerwear,
      tops: analyze_tops,
      bottoms: analyze_bottoms,
      footwear: analyze_footwear,
      accessories: analyze_accessories
    }
  end

  private

  def empty_recommendations
    {
      outerwear: "No data available",
      tops: "No data available",
      bottoms: "No data available",
      footwear: "No data available",
      accessories: "No data available"
    }
  end

  def temp_range
    @temp_range ||= begin
      temps_min = @forecasts.map(&:temperature_min).compact
      temps_max = @forecasts.map(&:temperature_max).compact
      temps_avg = @forecasts.map(&:temperature_avg).compact

      {
        min: temps_min.min,
        max: temps_max.max,
        avg: temps_avg.any? ? temps_avg.sum / temps_avg.size : 0
      }
    end
  end

  def max_uv_index
    @max_uv_index ||= @forecasts.map(&:uv_index_max).compact.max || 0
  end

  def will_rain?
    @forecasts.any? { |f| (f.precipitation_probability || 0) > RAIN_THRESHOLD }
  end

  def high_uv?
    @forecasts.any? { |f| (f.uv_index_max || 0) >= HIGH_UV }
  end

  def analyze_outerwear
    avg_temp = temp_range[:avg]

    recommendation = if avg_temp < VERY_COLD
      "Heavy winter coat or insulated parka"
    elsif avg_temp < COLD
      "Winter jacket or heavy sweater"
    elsif avg_temp < COOL
      "Light jacket, cardigan, or sweater"
    else
      "Light cardigan or no jacket needed"
    end

    recommendation += ". Also bring a waterproof rain jacket" if will_rain?
    recommendation
  end

  def analyze_tops
    avg_temp = temp_range[:avg]

    if avg_temp < VERY_COLD
      "Thermal base layers and long-sleeve sweaters"
    elsif avg_temp < COLD
      "Long-sleeve shirts and sweaters"
    elsif avg_temp < COOL
      "Long-sleeve shirts or light sweaters"
    elsif avg_temp < WARM
      "T-shirts, polo shirts, and light tops"
    else
      "T-shirts, tank tops, and breathable fabrics"
    end
  end

  def analyze_bottoms
    min_temp = temp_range[:min]

    if min_temp < VERY_COLD
      "Insulated pants or jeans with thermal layers"
    elsif min_temp < COOL
      "Jeans or casual pants"
    else
      "Shorts, light pants, or skirts"
    end
  end

  def analyze_footwear
    if will_rain?
      "Waterproof boots or water-resistant shoes"
    elsif temp_range[:min] < COLD
      "Insulated boots or closed-toe shoes"
    else
      "Sneakers, sandals, or comfortable walking shoes"
    end
  end

  def analyze_accessories
    items = []

    items << "Umbrella" if will_rain?
    items << "Hat, scarf, and gloves" if temp_range[:min] < VERY_COLD
    if high_uv? || temp_range[:max] > WARM
      items << "Sunglasses and sunscreen (UV index #{max_uv_index})"
    end

    items.any? ? items.join(", ") : "No special accessories needed"
  end
end
