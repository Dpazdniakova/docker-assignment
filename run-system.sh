#!/bin/sh

set -e # stop immediately if any command fails
LABEL="project=chinook-agent" #  label for easier cleanup

docker build --target seeder -t chinook-seeder --label "$LABEL" . # build the seeder image
docker build --target agent -t agent --label "$LABEL" . # build the agent image

docker network create --label "$LABEL" project-net # setup bridge network for the project 

# start the postgres container 
docker run -d --name chinook-db --network chinook-net --label "$LABEL" \ 
  -e POSTGRES_USER=chinook_user \
  -e POSTGRES_PASSWORD=chinook_pass \
  -e POSTGRES_DB=chinook \
  postgres:latest
  