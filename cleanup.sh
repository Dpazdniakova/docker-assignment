#!/bin/sh
LABEL="project=chinook-agent" # same label

# Remove labelled containers   
docker rm -f $(docker ps -aq --filter "label=$LABEL")

