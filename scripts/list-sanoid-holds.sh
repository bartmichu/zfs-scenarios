#!/bin/bash

/usr/sbin/zfs list -H -o name -t snapshot | /usr/bin/grep autosnap | while read -r SNAPSHOT; do
  HOLDS=$(/usr/sbin/zfs holds -H "$SNAPSHOT")

  if [ -n "$HOLDS" ]; then
    echo "Holds for: $SNAPSHOT"
    printf '%s\n' "$HOLDS" | /usr/bin/awk '{print $2}'
  fi
done
