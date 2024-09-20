#!/bin/bash

# Check if the network exists, if not create it
if ! docker network inspect coolify >/dev/null 2>&1; then
    echo "Creating coolify network..."
    docker network create coolify
else
    echo "Coolify network already exists."
fi

# Remove old containers (only if they exist)
if docker-compose ps -q | grep -q .; then
    echo "Removing old containers..."
    docker-compose down --remove-orphans
else
    echo "No existing containers to remove."
fi

# Start new containers
echo "Starting new containers..."
docker-compose up -d

# Follow logs
echo "Following logs..."
docker-compose logs -f