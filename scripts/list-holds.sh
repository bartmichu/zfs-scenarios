#!/bin/bash

###########
## This script lists all ZFS holds on snapshots matching the pattern.
## It is useful for identifying snapshots that are being prevented from
## deletion by syncoid or other tool.
###########

PATTERN="autosnap"

/usr/sbin/zfs list -H -o name -t snapshot | /usr/bin/grep "$PATTERN" | while read -r SNAPSHOT; do
  HOLDS=$(/usr/sbin/zfs holds -H "$SNAPSHOT")

  if [ -n "$HOLDS" ]; then
    echo "Holds for: $SNAPSHOT"
    printf '%s\n' "$HOLDS" | /usr/bin/awk '{print $2}'
  fi
done
