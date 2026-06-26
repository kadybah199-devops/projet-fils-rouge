#!/bin/bash

apt-get update -y

apt-get install -y \
    curl \
    git \
    ca-certificates \
    software-properties-common

# Docker
curl -fsSL https://get.docker.com | sh

usermod -aG docker vagrant

# Docker Compose V2 (IMPORTANT)
apt-get install -y docker-compose-plugin

# Vérification
docker --version
docker compose version