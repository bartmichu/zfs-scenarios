# ZFS Replication - USB Replication with zrepl

**The scenario:**

**System contains a ZFS pool that needs to be backed up to an encrypted USB drive. Different retention policies should be applied: the source pool retains a shorter snapshot history to conserve local space, while the target USB pool maintains a longer archival history.**

## 1. Install required packages

   If necessary, set up the zrepl repository. Follow the detailed instructions in the [installation section of the zrepl documentation](https://zrepl.github.io/installation/apt-repos.html).

   Install zrepl:

   ```bash
   sudo apt install zrepl
   ```

## 2. Prepare the external drive with the target data pool

1. Create the target data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on backuppool1 /dev/disk/by-id/<disk-id>
   ```

2. Create the dataset structure.

   Create an encrypted dataset for replication without `raw` mode (used with unencrypted source datasets; the target knows the encryption key):

   ```bash
   sudo zfs create -o encryption=on -o keyformat=passphrase backuppool1/encrypted
   ```

   Create an unencrypted dataset for replication in `raw` mode (used with encrypted source datasets; the target does not know the encryption key):

   ```bash
   sudo zfs create backuppool1/raw
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
             grid: 1x1h(keep=all) | 24x1h | 7x1d | 2x7d | 1x30d
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
           # Retention policy on the target filesystem (keeps only snapshots created by zrepl)
           - type: grid
             grid: 1x1h(keep=all) | 48x1h | 14x1d | 4x7d | 3x30d
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
           # Retention policy on the target filesystem (keeps only snapshots created by zrepl)
           - type: grid
             grid: 1x1h(keep=all) | 48x1h | 14x1d | 4x7d | 3x30d
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

1. If necessary, import the data pool and load the encryption key:

   ```bash
   sudo zpool import backuppool1

   zfs get keystatus -r backuppool1/encrypted
   sudo zfs load-key backuppool1/encrypted
   ```

2. Initiate replication.

   For encrypted source data pool:

   ```bash
   sudo zrepl signal wakeup userdata-push-usb-raw
   sudo zrepl status
   ```

   For unencrypted source data pool:

   ```bash
   sudo zrepl signal wakeup userdata-push-usb
   sudo zrepl status
   ```

## 5. Notes

- For `raw` replications, ensure you also maintain a backup of the encryption key from the source system.

- The initial replication must be performed to a non-existent dataset, for example `backuppool1/raw/<hostname1>` (`<hostname1>` will be created automatically during the first replication).

- You should customize the `grid` policies to match your requirements.

- Please visit the [zrepl documentation](https://zrepl.github.io/configuration.html) for explanations of all zrepl options.

- This scenario was tested on Ubuntu Desktop 25.10.
