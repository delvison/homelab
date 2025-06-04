#!/usr/bin/env bash

for i in {1..5}; do
    if torsocks curl -s -L http://check.torproject.org/api/ip | grep -q '"IsTor":true'; then
        echo "Tor connection successful"
        exit 0
    fi
    echo "Tor connection failed. Will try again..."
    sleep 30
done

echo "Tor connection failed after 5 attempts"
exit 1
