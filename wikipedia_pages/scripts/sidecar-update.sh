#!/bin/sh
set -e

WAIT_TIME=$((RANDOM % 601 + 300))
echo "Waiting $WAIT_TIME seconds (between 5-15 minutes) before downloading random page..."
sleep $WAIT_TIME

echo "Downloading random Wikipedia page..."
curl -L -o /www/index.html https://en.wikipedia.org/wiki/Special:Random
echo "Random page downloaded and saved"

