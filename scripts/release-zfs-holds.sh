#!/bin/bash

###########
## This script releases any existing holds on snapshots that match
## the pattern.
###########

PATTERN="autosnap"

/usr/sbin/zfs list -H -o name -t snapshot | /usr/bin/grep "$PATTERN" | while read -r SNAPSHOT; do
  HOLDS=$(/usr/sbin/zfs holds -H "$SNAPSHOT")

  if [ -n "$HOLDS" ]; then
    echo "Releasing holds for: $SNAPSHOT"
    printf '%s\n' "$HOLDS" | /usr/bin/awk '{print $2, $1}' | /usr/bin/xargs -r -n2 /usr/bin/sudo /usr/sbin/zfs release
  fi
done
