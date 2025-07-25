# Use minimal Ubuntu base
FROM ubuntu:22.04

# Install only what we need
RUN apt-get update && \
  apt-get install -y \
    curl \
    git \
    bash \
    postgresql-client \
    inotify-tools \
    locales && \
  apt-get clean

# Set up UTF-8 locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install mise
RUN curl https://mise.run | sh
ENV PATH="/root/.local/bin:${PATH}"

# Set up working directory
WORKDIR /app

# Copy .tool-versions from parent directory
COPY ../.tool-versions .

# Install Erlang and Elixir via mise
RUN mise install

# Install hex and rebar (with mise activated)
RUN /bin/bash -c 'eval "$(mise activate bash)" && \
    mix local.hex --force && \
    mix local.rebar --force'

# Ensure mise is activated in bash
RUN echo 'eval "$(mise activate bash)"' >> ~/.bashrc

