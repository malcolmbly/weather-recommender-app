class RecommendationAnalyzerJob < ApplicationJob
  queue_as :analysis

  def perform(trip_id)
    trip = Trip.find(trip_id)

    # Wrap in instrumentation for monitoring
    ActiveSupport::Notifications.instrument("trip.analysis_duration", trip_id: trip_id) do
      # Get all forecasts for this trip (ordered by date)
      forecasts = trip.forecasts.order(:date)

      if forecasts.any?
        # Analyze weather and generate recommendations
        analyzer = ClothingAnalyzer.new(forecasts)
        recommendations_data = analyzer.analyze

        # Create recommendation records for each category
        recommendations_data.each do |category, details|
          trip.recommendations.create!(
            clothing_category: category.to_s,
            details: details
          )
        end

        # Update trip status to ready
        trip.update!(status: :ready)
        Rails.logger.info("Analysis completed for trip #{trip_id}: #{recommendations_data.keys.count} recommendations created")
      else
        # No forecasts available - this shouldn't happen if ForecastFetcherJob succeeded
        Rails.logger.warn("No forecasts available for trip #{trip_id}")
        trip.update!(status: :failed)
      end
    end
  rescue StandardError => e
    Rails.logger.error("Analysis failed for trip #{trip_id}: #{e.message}")
    trip.update!(status: :failed)
    raise  # Re-raise to let Solid Queue retry mechanism handle it
  end
end
