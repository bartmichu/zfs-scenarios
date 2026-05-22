# Local USB backups (syncoid)

**Local ZFS backups. Syncoid creates recursive, semi-ephemeral snapshots at runtime and replicates them to an external drive. Both encrypted-send-to-untrusted-receiver (raw) and send-plain-encrypt-on-receive (non-raw) modes are supported.**

## 1. Install required packages

   ```bash
   sudo apt install zfsutils-linux mbuffer sanoid
   ```

## 2. Prepare the external drive with the destination data pool

1. Create the destination data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on backuppool1 /dev/disk/by-id/<disk-id>
   ```

2. Create the dataset structure.

   Create the parent dataset, unique for each source system (`workstation1`, `workstation2` etc.):

   ```bash
   sudo zfs create -o canmount=off -o mountpoint=legacy -p backuppool1/external/workstation1
   ```

   Create an unencrypted dataset for raw mode replication, used with encrypted source datasets when the transmitted data is already encrypted and the encryption key on the destination dataset does not need to be loaded:

   ```bash
   sudo zfs create -o canmount=off backuppool1/external/workstation1/raw
   ```

   Create an encrypted dataset for non-raw mode replication, used with encrypted or unencrypted source datasets when the transmitted data is encrypted while being written to the destination dataset using a separate encryption key:

   ```bash
   sudo zfs create -o canmount=off -o encryption=on -o keyformat=passphrase backuppool1/external/workstation1/encrypted
   ```

## 3. Perform the replication

1. Connect the external drive and import the data pool:

   ```bash
   sudo zpool import backuppool1
   ```

2. If necessary (non-raw mode), load the encryption key on the destination dataset:

   ```bash
   zfs get keystatus -r backuppool1/external | grep encrypted
   sudo zfs load-key backuppool1/external/workstation1/encrypted
   ```

3. Initiate replication, preferably using a terminal multiplexer like `tmux`.

   Recursive replication using semi-ephemeral snapshots created by Syncoid at runtime, using `hold`:

   - For raw mode:
  
     ```bash
     sudo syncoid --sendoptions=w --recursive --no-stream --use-hold rpool/USERDATA backuppool1/external/workstation1/raw/USERDATA
     ```

   - For non-raw mode:

     ```bash
     sudo syncoid --recursive --no-stream --use-hold rpool/USERDATA backuppool1/external/workstation1/encrypted/USERDATA
     ```

4. After all replications are finished, export the data pool and disconnect the drive:

   ```bash
   sudo zpool export backuppool1
   ```

## 4. Notes

- Test your backups.

- Test your restoration procedure.

- For raw replications, ensure that you also maintain a backup of the encryption key from the source system; otherwise, these backups will be worthless.

- The initial replication must be performed to a non-existent dataset, for example `backuppool1/external/workstation1/encrypted/<dataset-name>` (`<dataset-name>` will be created automatically during the first replication).

- Udev rules can be implemented to automatically trigger replication.

- Please visit the [Sanoid wiki](https://github.com/jimsalterjrs/sanoid/wiki) for explanations of all Syncoid options and Sanoid configuration.

- This scenario was tested on Ubuntu Desktop 26.04 with Sanoid 2.3.0.
