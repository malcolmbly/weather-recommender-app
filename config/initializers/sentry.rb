Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"] || Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Only enable in production
  config.enabled_environments = %w[production]

  # Filter out common exceptions that aren't actionable
  config.excluded_exceptions += [ "ActionController::RoutingError", "ActiveRecord::RecordNotFound" ]

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = true
end
