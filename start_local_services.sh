#!/bin/bash
# Start all microservices locally (non-Docker) for testing

# Set local database path for job_svc
export DATABASE_PATH="./apps/job_svc/db/job_service.db"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting microservices locally...${NC}"
echo "Press Ctrl+C to stop all services"
echo ""

# Function to start a service
start_service() {
  local service_dir=$1
  local service_name=$2
  local port=$3

  echo -e "${GREEN}Starting $service_name on port $port...${NC}"
  cd "$service_dir" && PORT=$port mix run --no-halt 2>&1 | sed "s/^/[$service_name] /" &
  local pid=$!
  echo "$pid" >> /tmp/msvc_local_pids.txt
  cd - > /dev/null
}

# Clean up previous PIDs file
rm -f /tmp/msvc_local_pids.txt

# Start services
start_service "/Users/nevendrean/code/elixir/msvc/apps/user_svc" "user_svc" 8081
sleep 2

start_service "/Users/nevendrean/code/elixir/msvc/apps/job_svc" "job_svc" 8082
sleep 2

start_service "/Users/nevendrean/code/elixir/msvc/apps/email_svc" "email_svc" 8083
sleep 2

start_service "/Users/nevendrean/code/elixir/msvc/apps/image_svc" "image_svc" 8084
sleep 2

echo ""
echo -e "${GREEN}All services started!${NC}"
echo "Services running:"
echo "  - user_svc:   http://localhost:8081"
echo "  - job_svc:    http://localhost:8082"
echo "  - email_svc:  http://localhost:8083"
echo "  - image_svc:  http://localhost:8084"
echo "  - client_svc: http://localhost:4000 (already running)"
echo ""
echo "To stop all services: kill \$(cat /tmp/msvc_local_pids.txt)"
echo ""

# Wait for Ctrl+C
trap 'echo ""; echo "Stopping services..."; kill $(cat /tmp/msvc_local_pids.txt) 2>/dev/null; rm -f /tmp/msvc_local_pids.txt; exit 0' INT
wait
