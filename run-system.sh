#!/bin/sh

set -e # stop immediately if any command fails
LABEL="project=chinook-agent" #  label for easier cleanup

docker build --target seeder -t chinook-seeder --label "$LABEL" . # build the seeder image
docker build --target agent -t agent --label "$LABEL" . # build the agent image

docker network create --label "$LABEL" chinook-net # setup bridge network for the project 
docker volume create --label "$LABEL" chinook-pgdata # create a named volume for postgress for future cleanup ( postgress will create a volume automatically if not specified)

# start the postgres container 
docker run -d --name chinook-db --network chinook-net --label "$LABEL" \
  -e POSTGRES_USER=chinook_user \
  -e POSTGRES_PASSWORD=chinook_pass \
  -e POSTGRES_DB=chinook \
  -v chinook-pgdata:/var/lib/postgresql \
  postgres:latest
  
# await until the db logs show it's accepting tcp connections 
  echo "Waiting for database..."
until docker logs chinook-db 2>&1 | grep -q 'listening on IPv4 address'; do
  sleep 2
done

# Start up the seeder container in the foreground , db file bind mounted as read only, --rm ensures the seeder self removes after its done
docker run --rm --name chinook-seeder --network chinook-net --label "$LABEL" \
  -v "$(pwd)/Chinook.db:/app/Chinook.db:ro" \
  -e SQLITE_FILE=/app/Chinook.db \
  -e DATABASE_URL=postgres://chinook_user:chinook_pass@chinook-db:5432/chinook \
  chinook-seeder

# Starting  the mcp-gateway in the background, which spins up the mcp server 
docker run -d --name mcp-gateway --network chinook-net --label "$LABEL" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)/mcp_config.yaml:/mcp_config.yaml:ro" \
  -v "$(pwd)/mcp_secret.env:/run/secrets/database-url:ro" \
  docker/mcp-gateway:latest \
  --transport=sse \
  --secrets=/run/secrets/database-url \
  --allow-unauthenticated \
  --servers=cockroachdb \
  --tools=execute_query \
  --config=/mcp_config.yaml

# Await the gateway
echo "Waiting for MCP gateway..."
until docker logs mcp-gateway 2>&1 | grep -q 'Start sse server on port 8811'; do
  sleep 2
done

# Start the one shot agent in the foreground 
docker run --rm --name agent --network chinook-net --label "$LABEL" \
  -v "$(pwd)/secret.ollama-api-key:/run/secrets/openai-api-key:ro" \
  -e MCP_SERVER_URL=http://mcp-gateway:8811/sse \
  -e DATABASE_DIALECT=PostgreSQL \
  -e QUESTION="What are the top 3 albums by sales?" \
  -e OPENAI_API_BASE_URL=https://ollama.com/v1 \
  -e OPENAI_MODEL_NAME=gpt-oss:20b \
  agent