# Frederick HMIS Warehouse - Multi-stage Dockerfile
# Stage 1: Builder
FROM ruby:3.3-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    gnupg \
    libpq-dev \
    postgresql-client \
    freetds-dev \
    libproj-dev \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfile and lock
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# Copy package files
COPY package.json yarn.lock ./
RUN yarn install --production

# Copy app code
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE=placeholder RAILS_ENV=production bundle exec rake assets:precompile

# Stage 2: Runtime
FROM ruby:3.3-slim

# Install runtime dependencies (including PostGIS support)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    postgresql-client \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy app from builder
COPY --from=builder /app .

ENV PATH="/usr/local/bundle/bin:$PATH"
ENV RAILS_ENV=production

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Database setup and server start
CMD ["sh", "-c", "bundle exec rake db:migrate && bundle exec puma -t 5:5 -p 3000 -e $RAILS_ENV"]