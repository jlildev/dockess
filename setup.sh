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

# Dynamically configure/update desktop launcher shortcut
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cat <<EOF > "$DIR/wp-manager.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=WP Multisite Manager
Comment=Manage WordPress Multisite Docker Stack
Exec=$DIR/start.sh
Icon=network-server
Path=$DIR
Terminal=false
Categories=Development;
EOF
chmod +x "$DIR/wp-manager.desktop"

# Load environment variables from .env if it exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Set defaults if environment variables are not loaded/defined
DB_NAME=${DB_NAME:-"wordpress"}
DB_USER=${DB_USER:-"wpuser"}
DB_PASSWORD=${DB_PASSWORD:-"wppassword"}
DB_HOST=${DB_HOST:-"db"}
WP_URL=${WP_URL:-"http://localhost:8080"}
WP_TITLE=${WP_TITLE:-"WordPress Multisite"}
WP_ADMIN_USER=${WP_ADMIN_USER:-"admin"}
WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD:-"adminpassword"}
WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL:-"admin@example.com"}

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
    if $DOCKER_COMPOSE exec -T db mysqladmin ping -h"localhost" -u"$DB_USER" -p"$DB_PASSWORD" --silent >/dev/null 2>&1; then
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
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASSWORD" \
    --dbhost="$DB_HOST" \
    --allow-root

  echo -e "${YELLOW}Installing WordPress...${NC}"
  $DOCKER_COMPOSE exec -T php wp core install \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --allow-root

  echo -e "${YELLOW}Converting to Multisite (Subdirectory)...${NC}"
  $DOCKER_COMPOSE exec -T php wp core multisite-convert \
    --title="$WP_TITLE" \
    --allow-root

  # Fix permissions so wp-content and source files are fully writeable by php-fpm (www-data) and host user
  echo -e "${YELLOW}Configuring permissions for local src directory...${NC}"
  chmod -R 777 src

  echo -e "${GREEN}WordPress Multisite installed successfully!${NC}"
fi

echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}  WordPress Multisite is ready at: $WP_URL${NC}"
echo -e "${GREEN}  Admin Dashboard: $WP_URL/wp-admin${NC}"
echo -e "${GREEN}  Username: $WP_ADMIN_USER${NC}"
echo -e "${GREEN}  Password: $WP_ADMIN_PASSWORD${NC}"
echo -e "${GREEN}==================================================${NC}"
echo -e "${BLUE}You can put plugins and themes directly in: ./src/wp-content/${NC}"
