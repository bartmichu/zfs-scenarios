# ZFS Replication - USB Replication with zrepl

**The scenario:**

**System contains a ZFS pool that needs to be backed up to an encrypted USB drive.**

## 1. Install required packages

   If necessary, set up the zrepl repository. Follow the detailed instructions in the [installation section of the zrepl documentation](https://zrepl.github.io/installation/apt-repos.html).

   Install zrepl:

   ```bash
   sudo apt install zrepl
   ```

## 2. Prepare the external drive with the target data pool

1. Create the target data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on -O encryption=on -O keyformat=passphrase backuppool /dev/disk/by-id/<disk-id>
   ```

2. Create the target dataset, unique for each host:

   ```bash
   sudo zfs create -p backuppool/replica/hostname1
   ```

## 3. Configure zrepl

1. Add the appropriate configuration file:

   ```bash
   sudo nano /etc/zrepl/zrepl.yml
   ```

   ```yaml
   global:
     logging:
       - type: syslog
         format: human
         level: warn

   jobs:
     - name: snapshot-datapool
       type: snap
       filesystems:
         "datapool<": true
       snapshotting:
         type: periodic
         interval: 10m
         prefix: zrepl_
       pruning:
         keep:
           - type: grid
             grid: 1x1h(keep=all) | 24x1h | 7x1d | 2x7d | 1x30d
             regex: "zrepl_.*"
           - type: regex
             negate: true
             regex: "^zrepl_.*"

     - name: push-usbbackup-datapool
       type: push
       filesystems:
         "datapool<": true
       snapshotting:
         type: manual
       pruning:
         keep_sender:
           - type: regex
             regex: ".*"
         keep_receiver:
           - type: grid
             grid: 1x1h(keep=all) | 48x1h | 14x1d | 4x7d | 2x30d
             regex: "^zrepl_.*"
           - type: regex
             negate: true
             regex: "^zrepl_.*"
       connect:
         type: local
         listener_name: usbbackup_sink
         client_identity: hostname1
       #send:
       #  encrypted: true
       replication:
         protection:
           initial: guarantee_resumability
           incremental: guarantee_incremental

     - name: sink-usbbackup
       type: sink
       root_fs: "backuppool/replica/hostname1"
       serve:
         type: local
         listener_name: usbbackup_sink
   ```

   Verify the configuration file:

   ```bash
   zrepl configcheck
   ```

   Reload zrepl configuration:

   ```bash
   sudo systemctl restart zrepl.service
   ```

   Check the service to make sure there are no errors:

   ```bash
   sudo systemctl status zrepl.service
   ```

## 4. Perform the replication

1. If necessary, import the data pool and load the encryption key:

   ```bash
   sudo zpool import -l backuppool
   ```

2. Initiate replication:

   ```bash
   sudo zrepl signal wakeup push-usbbackup-datapool
   sudo zrepl status
   ```

## 5. Notes

- The initial replication must be performed to a non-existent dataset, for example `backuppool/replica/hostname1/<pool-name>` (`<pool-name>` will be created automatically during the first replication).

- Please visit the [zrepl documentation](https://zrepl.github.io/configuration.html) for explanations of all zrepl options.

- This scenario was tested on Ubuntu Desktop 25.10.
