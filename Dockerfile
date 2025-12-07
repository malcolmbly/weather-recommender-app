# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile supports both development (docker-compose) and production (Render) environments
# Development: docker compose up (uses volume mounts, all gems included)
# Production: Render deployment (production-only gems, precompiled assets)

# Build arguments for environment-specific configuration
ARG RUBY_VERSION=3.4.7
ARG RAILS_ENV=production

# Base stage with Ruby
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set environment variables
ENV BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Pass build arg to this stage
ARG RAILS_ENV

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
COPY vendor ./vendor

# Install gems based on environment
# Production: exclude development/test gems for smaller image
# Development/Test: include all gems for docker-compose
RUN if [ "$RAILS_ENV" = "production" ]; then \
      bundle config set --local deployment 'true' && \
      bundle config set --local without 'development test'; \
    fi && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Make all bin scripts executable
RUN chmod +x ./bin/* || true

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompile assets only for production
RUN if [ "$RAILS_ENV" = "production" ]; then \
      SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile; \
    fi


# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Puma by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
