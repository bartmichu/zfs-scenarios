#!/bin/bash

/usr/sbin/zfs list -H -o name -t snapshot | /usr/bin/grep autosnap | while read SNAPSHOT; do
  HOLDS=$(/usr/sbin/zfs holds -H "$SNAPSHOT")
  if [[ -n "$HOLDS" ]]; then
    echo "Holds for: $SNAPSHOT"
    echo "$HOLDS"
  fi
done
