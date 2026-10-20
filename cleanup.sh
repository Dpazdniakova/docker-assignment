#!/bin/sh
LABEL="project=chinook-agent" # same label

# Remove labelled containers   
docker rm -f $(docker ps -aq --filter "label=$LABEL")

# Ensure the mcp server is gone too before starting to remove the network, filter by ancestor instead of label as its not applicable.
docker rm -f $(docker ps -aq --filter "ancestor=mcp/cockroachdb")

# Remove the labelled network 
docker network rm $(docker network ls -q --filter "label=$LABEL")

# Remove the labelled volume
docker volume rm $(docker volume ls -q --filter "label=$LABEL")