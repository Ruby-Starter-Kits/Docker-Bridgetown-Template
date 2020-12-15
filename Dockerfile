FROM ruby:2.7.2-alpine AS builder

LABEL maintainer="Mike Rogers <me@mikerogers.io>"

RUN apk add --no-cache \
    #
    # required
    build-base libffi-dev \
    nodejs yarn tzdata \
    zlib-dev libxml2-dev libxslt-dev readline-dev bash \
    # Nice to haves
    git vim \
    #
    # Fixes watch file issues with things like HMR
    libnotify-dev

FROM builder as development

# Create a non-root user
# Otherwise folders like node_modules are owned by root.
ARG USER_ID=${USER_ID:-1000}
ARG GROUP_ID=${GROUP_ID:-1000}
ARG DOCKER_USER=${DOCKER_USER:-user}

RUN addgroup -g $GROUP_ID -S $GROUP_ID
RUN adduser --disabled-password -G $GROUP_ID --uid $USER_ID -S $DOCKER_USER

# Add the current apps files into docker image
RUN mkdir -p /usr/src/app
RUN chown -R $USER_ID:$GROUP_ID /usr/src/app
WORKDIR /usr/src/app

ENV PATH /usr/src/app/bin:$PATH

# Install latest bundler
RUN bundle config --global silence_root_warning 1

EXPOSE 4000
CMD ["yarn", "start", "--host", "0.0.0.0"]

# Define the user running the container
USER $USER_ID:$GROUP_ID

FROM development AS production

# Install Ruby Gems
COPY Gemfile /usr/src/app
COPY Gemfile.lock /usr/src/app
RUN bundle check || bundle install --jobs=$(nproc)

# Install Yarn Libraries
COPY package.json /usr/src/app
COPY yarn.lock /usr/src/app
RUN yarn install --check-files

# Copy the rest of the app
COPY . /usr/src/app

# Compile the assets
RUN RACK_ENV=production NODE_ENV=production yarn build
