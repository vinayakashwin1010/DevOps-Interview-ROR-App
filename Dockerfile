# Stage 1: Builder  
FROM ruby:3.2.2-alpine AS builder  

WORKDIR /app  
COPY Gemfile* .  
RUN apk add --no-cache build-base postgresql-dev nodejs yarn \  
    && bundle install --jobs=4 --without development test  

# Stage 2: Runtime  
FROM ruby:3.2.2-alpine  

WORKDIR /app  
COPY --from=builder /usr/local/bundle /usr/local/bundle  
COPY . .  

RUN apk add --no-cache postgresql-client tzdata \  
    && RAILS_ENV=production bundle exec rails assets:precompile  

EXPOSE 3000  
CMD ["bundle", "exec", "rails", "s", "-b", "0.0.0.0"]