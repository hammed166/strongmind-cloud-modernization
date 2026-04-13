# Use ruby:3.3-slim for smaller image size and compatibility with native gems.
# (Alpine is smaller but can cause issues with some gems; slim is a good production tradeoff.)
FROM ruby:3.3-slim AS builder

WORKDIR /app

# Install build dependencies and JS tools for asset compilation
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential libpq-dev nodejs yarn \
  && rm -rf /var/lib/apt/lists/*

# Install gems (excluding dev/test)
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test --jobs 4 --retry 3 \
  && rm -rf vendor/bundle/cache

# Copy application code and compile assets
COPY . .
RUN bundle exec rake assets:precompile

# =============================
# Final runtime image
# =============================
FROM ruby:3.3-slim

WORKDIR /app

# Create non-root user for security
RUN addgroup --system app && adduser --system --ingroup app app

# Install minimal runtime dependencies only
RUN apt-get update \
  && apt-get install -y --no-install-recommends libpq-dev nodejs \
  && rm -rf /var/lib/apt/lists/*

# Copy built app from builder, including precompiled assets and gems
COPY --from=builder /app /app

USER app

# Default to production mode, but allow override
ENV RAILS_ENV=production
ENV RACK_ENV=production

# Expose only the app port (do not expose unnecessary ports)
EXPOSE 3000

# Healthcheck: use Rails health endpoint (customize as needed)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the Rails server (Puma)
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
