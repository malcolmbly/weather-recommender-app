class ClothingAnalyzer
  # Temperature thresholds (Fahrenheit - API uses imperial units)
  VERY_COLD = 41.0    # Below this: heavy winter gear
  COLD = 50.0         # Below this: cold weather clothing
  COOL = 68.0         # Below this: light layers
  WARM = 77.0         # Above this: warm weather clothing
  HOT = 86.0          # Above this: hot weather clothing

  RAIN_THRESHOLD = 30.0  # Precipitation probability %
  HIGH_UV = 6            # UV index threshold

  def initialize(forecasts)
    @forecasts = forecasts.sort_by(&:date)
  end

  def analyze
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

  def temp_range
    @temp_range ||= {
      min: @forecasts.map(&:temperature_min).compact.min,
      max: @forecasts.map(&:temperature_max).compact.max,
      avg: @forecasts.map(&:temperature_avg).compact.sum / @forecasts.count
    }
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
    elsif avg_temp < WARM
      "Long-sleeve shirts or light sweaters"
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
    items << "Sunglasses and sunscreen (UV index #{@forecasts.map(&:uv_index_max).compact.max})" if high_uv? || temp_range[:max] > WARM

    items.any? ? items.join(", ") : "No special accessories needed"
  end
end
