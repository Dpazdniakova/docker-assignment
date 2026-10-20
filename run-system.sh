#!/bin/sh

set -e # stop immediately if any command fails
LABEL="project=chinook-agent" #  label for easier cleanup

docker build --target seeder -t chinook-seeder --label "$LABEL" . # build the seeder image
docker build --target agent -t agent --label "$LABEL" . # build the agent image

docker network create --label "$LABEL" project-net # setup bridge network for the project 
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