#!/bin/sh
LABEL="project=chinook-agent" # same label

# Remove labelled containers   
docker rm -f $(docker ps -aq --filter "label=$LABEL")

# Ensure the mcp server is gone too before starting to remove the network, filter by ancestor instead of label as its not applicable.
docker rm -f $(docker ps -aq --filter "ancestor=mcp/cockroachdb")
