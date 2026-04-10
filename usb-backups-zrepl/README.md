# Local USB backups (zrepl)

**Local ZFS backup to an encrypted USB drive. The source system creates, replicates, and prunes snapshots using zrepl. Snapshot creation and pruning are automated, while replication is triggered manually. The source pool maintains a shorter retention policy to conserve space, while the destination USB backup pool maintains a longer archival retention policy. Both encrypted-send-to-untrusted-receiver and send-plain-encrypt-on-receive modes are supported.**

## 1. Install required packages

   If necessary, set up the zrepl repository. Follow the detailed instructions in the [installation section of the zrepl documentation](https://zrepl.github.io/installation/apt-repos.html).

   Install zrepl:

   ```bash
   sudo apt install zrepl
   ```

## 2. Prepare the external drive with the destination data pool

1. Create the destination data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on backuppool1 /dev/disk/by-id/<disk-id>
   ```

2. Create the dataset structure.

   Create an unencrypted dataset for encrypted-send-to-untrusted-receiver replication (`raw` mode), used with encrypted source datasets when the sender transmits already encrypted data and the receiver stores it without being able to decrypt it:

   ```bash
   sudo zfs create backuppool1/raw
   ```

   Create an encrypted dataset for send-plain-encrypt-on-receive replication, used with encrypted or unencrypted source datasets when the sender transmits unencrypted data and the receiver encrypts it when writing to the destination dataset (the destination has the encryption key):

   ```bash
   sudo zfs create -o encryption=on -o keyformat=passphrase backuppool1/encrypted
   ```

## 3. Configure zrepl

1. Edit the main configuration file:

   ```bash
   sudo nano /etc/zrepl/zrepl.yml
   ```

   ```yaml
   global:
     logging:
       - type: syslog
         format: human
         level: warn
  
   include:
     - /etc/zrepl/userdata.yml
   ```

2. Edit the included configuration file:

   ```bash
   sudo nano /etc/zrepl/userdata.yml
   ```

   ```yaml
   # Activate this file by including it in the main configuration file

   jobs:
     - name: userdata-snap
       type: snap
       filesystems:
         "rpool/USERDATA<": true
       snapshotting:
         # Create source filesystem ZFS snapshots automatically at a fixed interval
         type: periodic
         interval: 10m
         prefix: zrepl_
       pruning:
         keep:
           - type: grid
             # Retention policy for source filesystem snapshots created by zrepl
             grid: 1x1h(keep=all) | 24x1h | 30x1d
             regex: "zrepl_.*"
           - type: regex
             # Preserve all snapshots NOT created by zrepl (e.g. manual snapshots or those from other tools)
             negate: true
             regex: "^zrepl_.*"

     - name: userdata-push-usb-raw
       # This job is for encrypted-send-to-untrusted-rceiver use case
       type: push
       filesystems:
         "rpool/USERDATA<": true
       snapshotting:
         # Snapshot creation is handled by the snapshot job
         type: manual
       pruning:
         keep_sender:
           # Source filesystem pruning is handled by the snapshot job
           - type: regex
             regex: ".*"
         keep_receiver:
           # Retention policy on the destination filesystem (keeps only snapshots created by zrepl)
           - type: grid
             grid: 1x1h(keep=all) | 24x1h | 60x1d | 6x30d
             regex: "^zrepl_.*"
       connect:
         type: local
         listener_name: userdata_backuppool1_raw
         client_identity: hostname1
       send:
         encrypted: true
       replication:
         protection:
           initial: guarantee_resumability
           incremental: guarantee_incremental

     - name: userdata-push-usb
       # This job is for send-plain-encrypt-on-receive use case
       type: push
       filesystems:
         "rpool/USERDATA<": true
       snapshotting:
         # Snapshot creation is handled by the snapshot job
         type: manual
       pruning:
         keep_sender:
           # Source filesystem pruning is handled by the snapshot job
           - type: regex
             regex: ".*"
         keep_receiver:
           # Retention policy on the destination filesystem (keeps only snapshots created by zrepl)
           - type: grid
             grid: 1x1h(keep=all) | 24x1h | 60x1d | 6x30d
             regex: "^zrepl_.*"
       connect:
         type: local
         listener_name: userdata_backuppool1
         client_identity: hostname1
       replication:
         protection:
           initial: guarantee_resumability
           incremental: guarantee_incremental

     - name: userdata-sink-usb-raw
       # This job is for encrypted-send-to-untrusted-rceiver use case
       type: sink
       root_fs: "backuppool1/raw"
       serve:
         type: local
         listener_name: userdata_backuppool1_raw
       recv:
         placeholder:
           encryption: off

     - name: userdata-sink-usb
       # This job is for send-plain-encrypt-on-receive use case
       type: sink
       root_fs: "backuppool1/encrypted"
       serve:
         type: local
         listener_name: userdata_backuppool1
       recv:
         placeholder:
           encryption: inherit
   ```

3. Verify the configuration file:

   ```bash
   zrepl configcheck
   ```

4. Reload zrepl configuration:

   ```bash
   sudo systemctl restart zrepl.service
   ```

5. Check the service to make sure there are no errors:

   ```bash
   sudo systemctl status zrepl.service
   ```

## 4. Perform the replication

1. If necessary, connect the drive and import the data pool:

   ```bash
   sudo zpool import backuppool1
   ```

2. Initiate replication.

   For encrypted-send-to-untrusted-receiver use case:

   ```bash
   sudo zrepl signal wakeup userdata-push-usb-raw
   sudo zrepl status
   ```

   For send-plain-encrypt-on-receive use case:

   ```bash
   zfs get -H -o value keystatus backuppool1/encrypted | grep -q unavailable && sudo zfs load-key backuppool1/encrypted

   sudo zrepl signal wakeup userdata-push-usb
   sudo zrepl status
   ```

3. After all jobs are finished, export the data pool and disconnect the drive:

   ```bash
   sudo zpool export backuppool1
   ```

## 5. Notes

- Test the restoration procedure.

- For `raw` replications (encrypted-send-to-untrusted-receiver), ensure that you also maintain a backup of the encryption key from the source system; otherwise, these backups will be worthless.

- The initial replication must be performed to a non-existent dataset, for example `backuppool1/raw/<hostname1>` (`<hostname1>` will be created automatically during the first replication).

- You should customize the `grid` policies to match your requirements.

- Please visit the [zrepl documentation](https://zrepl.github.io/configuration.html) for explanations of all zrepl options.

- This scenario was tested on Ubuntu Desktop 25.10 with zrepl 0.7.0.

## 6. The missing parts

- Configure Udev rules to automatically trigger replication.
