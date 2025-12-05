# ZFS Replication - USB Replication with Syncoid

**The scenario:**

**System contains a ZFS pool that needs to be backed up to an encrypted USB drive.**

## 1. Install required packages

   ```bash
   sudo apt install sanoid mbuffer
   ```

## 2. Prepare the external drive with the target data pool

1. Create the target data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on -O encryption=on -O keyformat=passphrase backuppool /dev/disk/by-id/<disk-id>
   ```

2. Create the target dataset, unique for each host:

   ```bash
   sudo zfs create -p backuppool/replicated/hostname1
   ```

## 3. Perform the replication

1. If necessary, import the data pool and load the encryption key:

   ```bash
   sudo zpool import -l backuppool
   ```

2. Initiate replication, preferably using a terminal multiplexer like `tmux`.

   Recursive replication using semi-ephemeral snapshots created by Syncoid at runtime. Using `hold`:
  
   ```bash
   sudo syncoid --recursive --no-stream --use-hold datapool backuppool/replicated/hostname1/datapool
   ```

   Recursive replication of only the the newest existing snapshots (without replicating the intermediate snapshots). Using `bookmark`, without using `hold`:

   ```bash
   sudo syncoid --recursive --no-sync-snap --no-stream --create-bookmark datapool backuppool/replicated/hostname1/datapool
   ```

## 4. Notes

- The initial replication must be performed to a non-existent dataset, for example `backuppool/replicated/hostname1/<pool-name>` (`<pool-name>` will be created automatically during the first replication).

- Please visit the [Sanoid wiki](https://github.com/jimsalterjrs/sanoid/wiki) for explanations of all Syncoid options.

- This scenario was tested on Ubuntu Server 24.04.
