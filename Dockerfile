# Base Image
FROM ruby:3.1-alpine


ENV APP_HOME /app
WORKDIR $APP_HOME


RUN apk add --no-cache build-base tzdata


COPY . .


RUN bundle install


COPY .env.example .env


ENV TZ=UTC

CMD ["bundle", "exec", "ruby", "bot.rb"]
