# Stage 1: Base stage with Podman fix applied
FROM mcr.microsoft.com/devcontainers/python:3-3.12-bookworm AS base-image
RUN chmod 1777 /tmp && echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/01no-sandbox

# Stage 2: Target stage for Devcontainers & remaining tools
FROM base-image

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    make \
    unzip \
    gnupg \
    ca-certificates \
    lsb-release \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Python tools
RUN pip install --no-cache-dir \
    ansible \
    ansible-lint \
    bandit \
    checkov \
    pre-commit