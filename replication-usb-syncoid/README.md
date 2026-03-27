# ZFS Replication - USB backup with Syncoid

**The scenario:**

**The system contains a ZFS pool or datasets that needs to be backed up to an encrypted USB drive. Sanoid is responsible for creating and pruning snapshots, while Syncoid is responsible for replicating them. Snapshot creation and pruning on source filesystem are handled automatically, while replication and target filesystem snapshot pruning must be initiated manually. Both the encrypted-send-to-untrusted-receiver and send-plain-encrypt-on-receive use cases are supported.**

## 1. Install required packages

   ```bash
   sudo apt install sanoid mbuffer
   ```

## 2. Prepare the external drive with the target data pool

1. Create the target data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on backuppool1 /dev/disk/by-id/<disk-id>
   ```

2. Create the dataset structure.

   Create an encrypted dataset for replication without `raw` mode (send-plain-encrypt-on-receive):

   ```bash
   sudo zfs create -o encryption=on -o keyformat=passphrase backuppool1/encrypted
   sudo zfs create backuppool1/encrypted/hostname1
   ```

   Create an unencrypted dataset for replication in `raw` mode (encrypted-send-to-untrusted-receiver):

   ```bash
   sudo zfs create -p backuppool1/raw/hostname1
   ```

## 3. Configure sanoid

   Edit the configuration file:

   ```bash
   sudo nano /etc/sanoid/sanoid.conf
   ```

   ```conf
   # hostname1

   [rpool/USERDATA]
     recursive = yes
     use_template = standard

   [template_ignore]
     autoprune = no
     autosnap = no
     monitor = no

   [template_standard]
     autoprune = yes
     autosnap = yes
     daily = 7
     frequent_period = 15
     frequently = 4
     hourly = 24
     monthly = 1
     weekly = 2
     yearly = 0
   ```

   ```bash
   sudo chmod 640 /etc/sanoid/sanoid.conf
   ```

   Reload Sanoid configuration:

   ```bash
   sudo systemctl restart sanoid.service
   ```

   Check the service and timer to make sure there are no errors:

   ```bash
   sudo systemctl status sanoid.service
   sudo systemctl status sanoid.timer
   ```

## 4. Perform the replication

1. If necessary, connect the drive and import the data pool:

   ```bash
   sudo zpool import backuppool1
   ```

2. Initiate replication, preferably using a terminal multiplexer like `tmux`.

   Recursive replication of only the the newest existing snapshots (without replicating the intermediate snapshots). Using `bookmark`, without using `hold`:

   - For encrypted-send-to-untrusted-receiver use case:

     ```bash
     sudo syncoid --sendoptions=w --recursive --no-sync-snap --no-stream --create-bookmark rpool/USERDATA backuppool1/raw/hostname1/USERDATA
     ```

   - For send-plain-encrypt-on-receive use case:

     ```bash
     zfs get -H -o value keystatus backuppool1/encrypted | grep -q unavailable && sudo zfs load-key backuppool1/encrypted

     sudo syncoid --recursive --no-sync-snap --no-stream --create-bookmark rpool/USERDATA backuppool1/encrypted/hostname1/USERDATA
     ```

3. After all replications are finished, export the data pool and disconnect the drive:

   ```bash
   sudo zpool export backuppool1
   ```

## 5. Notes

- For `raw` replications, ensure you also maintain a backup of the encryption key from the source system.

- The initial replication must be performed to a non-existent dataset, for example `backuppool1/raw/hostname1/<dataset-name>` (`<dataset-name>` will be created automatically during the first replication).

- You should customize the `autosnap` and `autoprune` policies to match your requirements.

- The above solution does not implement snapshot retention on the target pool.

- For recursive replication using semi-ephemeral snapshots created by Syncoid at runtime, using `hold`:
  
   ```bash
   sudo syncoid --recursive --no-stream --use-hold rpool/USERDATA backuppool1/encrypted/hostname1/USERDATA
   ```

- `encrypted-send-to-untrusted-receiver` use case: The sender transmits already encrypted data, and the receiver stores it without being able to decrypt it.

- `send-plain-encrypt-on-receive` use case: The sender transmits unencrypted data, and the receiver encrypts it when writing to the destination dataset.

- Please visit the [Sanoid wiki](https://github.com/jimsalterjrs/sanoid/wiki) for explanations of all Syncoid options.

- This scenario was tested on Ubuntu Desktop 25.10.
