#!/bin/bash
set -e

# Add common user bin paths to PATH
for path in "$HOME/.local/bin" "$HOME/bin"; do
  if [ -d "$path" ] && [[ ":$PATH:" != *":$path:"* ]]; then
    export PATH="$path:$PATH"
  fi
done

echo "Starting WordPress Multisite Manager..."

# Start browser opener in the background. It will wait for the manager to write its port.
(
  PORT=""
  for i in {1..30}; do
    if [ -f .manager_port ]; then
      PORT=$(cat .manager_port)
      break
    fi
    sleep 0.1
  done

  # Fallback default if not found
  PORT=${PORT:-8000}

  echo "WordPress Multisite Manager is running at: http://localhost:$PORT"

  if command -v xdg-open > /dev/null; then
    xdg-open "http://localhost:$PORT"
  elif command -v open > /dev/null; then
    open "http://localhost:$PORT"
  else
    echo "Please open your browser and navigate to: http://localhost:$PORT"
  fi
) &

# Run python manager server in the foreground.
# This ensures that hitting Ctrl+C or closing the terminal terminates the process immediately.
python3 manager.py


