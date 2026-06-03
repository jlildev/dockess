#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Add common user bin paths to PATH
for path in "$HOME/.local/bin" "$HOME/bin"; do
  if [ -d "$path" ] && [[ ":$PATH:" != *":$path:"* ]]; then
    export PATH="$path:$PATH"
  fi
done

# Detect docker-compose or docker compose
if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker-compose"
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker compose"
else
  echo -e "${RED}Error: Neither 'docker-compose' nor 'docker compose' was found in PATH.${NC}"
  echo -e "${RED}Please ensure Docker Compose is installed and in your PATH.${NC}"
  exit 1
fi

echo -e "${BLUE}=== Starting WordPress Multisite Setup ===${NC}"

# Ensure source directory exists
mkdir -p src

# Build and start Docker services
echo -e "${YELLOW}Starting containers...${NC}"
$DOCKER_COMPOSE up -d --build

# Function to wait for MySQL to be ready
wait_for_db() {
  echo -e "${YELLOW}Waiting for MySQL database to be ready...${NC}"
  local max_attempts=30
  local attempt=1
  while [ $attempt -le $max_attempts ]; do
    if $DOCKER_COMPOSE exec -T db mysqladmin ping -h"localhost" -u"wpuser" -p"wppassword" --silent >/dev/null 2>&1; then
      echo -e "${GREEN}Database is ready!${NC}"
      return 0
    fi
    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
  done
  echo -e "\nError: Database failed to start in time."
  exit 1
}

wait_for_db

# Check if WordPress is already installed
if [ -f "src/wp-config.php" ]; then
  echo -e "${GREEN}WordPress is already installed.${NC}"
else
  echo -e "${YELLOW}Downloading WordPress...${NC}"
  $DOCKER_COMPOSE exec -T php wp core download --allow-root

  echo -e "${YELLOW}Creating wp-config.php...${NC}"
  $DOCKER_COMPOSE exec -T php wp config create \
    --dbname=wordpress \
    --dbuser=wpuser \
    --dbpass=wppassword \
    --dbhost=db \
    --allow-root

  echo -e "${YELLOW}Installing WordPress...${NC}"
  $DOCKER_COMPOSE exec -T php wp core install \
    --url="http://localhost:8080" \
    --title="WordPress Multisite" \
    --admin_user="admin" \
    --admin_password="adminpassword" \
    --admin_email="admin@example.com" \
    --allow-root

  echo -e "${YELLOW}Converting to Multisite (Subdirectory)...${NC}"
  $DOCKER_COMPOSE exec -T php wp core multisite-convert \
    --title="WordPress Multisite Network" \
    --allow-root

  # Fix permissions so wp-content and source files are fully writeable by php-fpm (www-data) and host user
  echo -e "${YELLOW}Configuring permissions for local src directory...${NC}"
  chmod -R 777 src

  echo -e "${GREEN}WordPress Multisite installed successfully!${NC}"
fi

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}  WordPress Multisite is ready at: http://localhost:8080${NC}"
echo -e "${GREEN}  Admin Dashboard: http://localhost:8080/wp-admin${NC}"
echo -e "${GREEN}  Username: admin${NC}"
echo -e "${GREEN}  Password: adminpassword${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "${BLUE}You can put plugins and themes directly in: ./src/wp-content/${NC}"
