Sentry.init do |config|
  config.dsn = "https://8befd9210e1d80c4f0a4b8a3fcdf9eb5@o4510484657799168.ingest.us.sentry.io/4510484658913280"
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = true
end
