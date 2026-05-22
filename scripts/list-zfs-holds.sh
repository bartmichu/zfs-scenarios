#!/bin/bash

###########
## This script lists all holds on snapshots that match the pattern.
###########

PATTERN="autosnap"

/usr/sbin/zfs list -H -o name -t snapshot | /usr/bin/grep "$PATTERN" | while read -r SNAPSHOT; do
  HOLDS=$(/usr/sbin/zfs holds -H "$SNAPSHOT")

  if [ -n "$HOLDS" ]; then
    echo "Holds for: $SNAPSHOT"
    printf '%s\n' "$HOLDS" | /usr/bin/awk '{print $2}'
  fi
done
