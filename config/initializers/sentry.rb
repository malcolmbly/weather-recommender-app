Sentry.init do |config|
  config.dsn = "https://78e332cffff32da7494768bd90bcd3a4@o4510484657799168.ingest.us.sentry.io/4510484790837248"
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Only enable in production
  config.enabled_environments = %w[production]

  # Filter out common exceptions that aren't actionable
  config.excluded_exceptions += ['ActionController::RoutingError', 'ActiveRecord::RecordNotFound']

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = true
end
