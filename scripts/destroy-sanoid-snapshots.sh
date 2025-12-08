#!/bin/bash

/usr/sbin/zfs list -H -o name -t snapshot | /usr/bin/grep autosnap | while read SNAPSHOT; do
  HOLDS=$(/usr/bin/sudo /usr/sbin/zfs holds -H "$SNAPSHOT")

  if [ -n "$HOLDS" ]; then
    echo "Releasing holds for: $SNAPSHOT"
    echo "$HOLDS" | /usr/bin/awk '{print $2, $1}' | /usr/bin/xargs -r -n2 /usr/bin/sudo /usr/sbin/zfs release
  fi

  echo "Destroying snapshot: $SNAPSHOT"
  /usr/bin/sudo /usr/sbin/zfs destroy "$SNAPSHOT"
done
