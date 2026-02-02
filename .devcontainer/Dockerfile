# Matches .ruby-version
ARG RUBY_VERSION=3.4.7
FROM ruby:${RUBY_VERSION}

# postCreateCommand runs "bundle install && rake"
RUN gem install bundler

ENV BINDING="0.0.0.0"
