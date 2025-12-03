class ForecastFetcherJob < ApplicationJob
  queue_as :weather_fetch

  retry_on ForecastProcessor::ProcessingError,
           wait: :polynomially_longer,
           attempts: 3

  def perform(trip_id)
    trip = Trip.find(trip_id)
    trip.update!(status: :processing)

    # Wrap in instrumentation for monitoring
    ActiveSupport::Notifications.instrument("trip.forecast_fetch", trip_id: trip_id) do
      processor = ForecastProcessor.new(trip: trip)
      forecasts = processor.process

      Rails.logger.info("Successfully fetched #{forecasts.count} forecasts for trip #{trip_id}")

      # Enqueue next job in the workflow
      RecommendationAnalyzerJob.perform_later(trip.id)
    end
  rescue ForecastProcessor::ProcessingError => e
    Rails.logger.error("Forecast fetch failed for trip #{trip_id}: #{e.message}")
    trip.update!(status: :failed)
    raise # Let Solid Queue retry mechanism handle it
  rescue StandardError => e
    Rails.logger.error("Unexpected error in ForecastFetcherJob for trip #{trip_id}: #{e.message}")
    trip.update!(status: :failed)
    raise
  end
end
