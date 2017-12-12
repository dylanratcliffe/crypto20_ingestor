FROM ruby:2.1
MAINTAINER Dylan Ratcliffe <dylan.ratcliffe@puppet.com>

RUN mkdir /app
WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN bundle install -j 8 --without development

COPY . /app

CMD ["bundle", "exec", "ruby", "ingest.rb"]
