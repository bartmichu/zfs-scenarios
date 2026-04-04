# ZFS Replication - SSH Push Replication with Syncoid

**The scenario:**

**Workstation contains a ZFS pool or datasets that needs to be backed up off-site to backup server. The backup should run in push mode and use minimal privileges on both sides. The backup server should maintain its own independent retention policy. If the source pool is encrypted, the backup server must not require access to the decrypted data or the workstation's encryption keys. If the source pool is not encrypted, server-side encryption can be used instead.**

## 1. Create a dedicated user account on the system with the target data pool (all commands are executed as `admin@backupserver1`)

1. Create a dedicated user account:

   ```bash
   sudo adduser zfs-push-receiver
   ```

## 2. Prepare the system with the source data pool (all commands are executed as `admin@workstation1`)

1. Install required packages:

   ```bash
   sudo apt install zfsutils-linux sanoid mbuffer
   ```

2. Create a dedicated user account:

   ```bash
   sudo adduser zfs-push-sender
   ```

3. Create a key pair for the dedicated user and add the public key to the system with the target data pool:

   ```bash
   su - zfs-push-sender
   ssh-keygen -t ed25519 -f ~/.ssh/backupserver1
   ssh-copy-id -i ~/.ssh/backupserver1.pub zfs-push-receiver@backupserver1
   exit
   ```

4. Grant minimal required permissions using ZFS permission delegation:

   ```bash
   sudo zfs allow -u zfs-push-sender bookmark,hold,release,send rpool/USERDATA
   ```

5. Configure Sanoid (for replication with the `--no-sync-snap` option, an additional snapshot creation mechanism is required).

   Edit the configuration file:

   ```bash
   sudo nano /etc/sanoid/sanoid.conf
   ```

   ```conf
   # workstation1

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

## 3. Prepare the system with the target data pool (all commands are executed as `admin@backupserver1`)

1. Install required packages:

   ```bash
   sudo apt install zfsutils-linux sanoid mbuffer
   ```

2. Configure the SSH server:

   ```bash
   sudo nano /etc/ssh/sshd_config.d/zfs-push-receiver.conf
   ```

   ```conf
   # backupserver1

   Match User zfs-push-receiver
     AllowUsers *@<workstation1-ip> #replace the IP address
     AuthenticationMethods publickey
     Banner none
     GatewayPorts no
     PasswordAuthentication no
     PermitTTY no
     PermitTunnel no
     X11Forwarding no
   ```

   ```bash
   sudo chmod 640 /etc/ssh/sshd_config.d/zfs-push-receiver.conf
   ```

   Test and apply the SSH server configuration:

   ```bash
   sudo sshd -t -f /etc/ssh/sshd_config.d/zfs-push-receiver.conf && sudo systemctl restart ssh.socket
   ```

3. If necessary, create the target data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on backuppool1 /dev/disk/by-id/<disk-id>
   ```

4. Create the dataset structure.

   Create the parent dataset, unique for each client:

   ```bash
   sudo zfs create -p backuppool1/push-received/workstation1
   ```

   Create an encrypted dataset for replication without `raw` mode (used with unencrypted source datasets; the target knows the encryption key):

   ```bash
   sudo zfs create -o encryption=on -o keyformat=passphrase backuppool1/push-received/workstation1/encrypted
   ```

   Create an unencrypted dataset for replication in `raw` mode (used with encrypted source datasets; the target does not know the encryption key):

   ```bash
   sudo zfs create backuppool1/push-received/workstation1/raw
   ```

5. Grant required permissions using ZFS permission delegation:

   ```bash
   sudo zfs allow -u zfs-push-receiver create,hold,mount,receive,release backuppool1/push-received/workstation1/encrypted
   sudo zfs allow -u zfs-push-receiver create,hold,mount,receive,release backuppool1/push-received/workstation1/raw
   ```

6. Configure Sanoid to delete old snapshots.

   Edit the configuration file:

   ```bash
   sudo nano /etc/sanoid/sanoid.conf
   ```

   ```conf
   # backupserver1

   [backuppool1/push-received/workstation1/encrypted]
     process_children_only = yes
     recursive = yes
     use_template = replica

   [backuppool1/push-received/workstation1/raw]
     process_children_only = yes
     recursive = yes
     use_template = replica

   [template_ignore]
     autoprune = no
     autosnap = no
     monitor = no

   [template_replica]
     autoprune = yes
     autosnap = no
     daily = 14
     daily_crit = 36h
     daily_warn = 25h
     frequent_period = 15
     frequently = 4
     frequently_crit = 0
     frequently_warn = 0
     hourly = 48
     hourly_crit = 24h
     hourly_warn = 2h
     monitor = yes
     monthly = 2
     monthly_crit = 36d
     monthly_warn = 32d
     weekly = 4
     weekly_crit = 12d
     weekly_warn = 8d
     yearly = 0
     yearly_crit = 0
     yearly_warn = 0
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

1. If necessary, load the encryption key on the target server (executed as `admin@backupserver1`):

   ```bash
   zfs get keystatus -r backuppool1/push-received | grep encrypted
   sudo zfs load-key backuppool1/push-received/workstation1/encrypted
   ```

2. Initiate replication, preferably using a terminal multiplexer like `tmux` (all commands are executed as `zfs-push-sender@workstation1`).

   - For encrypted-send-to-untrusted-receiver use case: recursive replication of all already existing snapshots, using `raw` mode:

      ```bash
      syncoid --sendoptions=w --no-privilege-elevation --recursive --no-sync-snap --no-rollback --use-hold --sshkey ~/.ssh/backupserver1 rpool/USERDATA zfs-push-receiver@backupserver1:backuppool1/push-received/workstation1/raw/USERDATA
      ```

   - For send-plain-encrypt-on-receive use case: recursive replication of all already existing snapshots:

      ```bash
      syncoid --no-privilege-elevation --recursive --no-sync-snap --no-rollback --use-hold --sshkey ~/.ssh/backupserver1 rpool/USERDATA zfs-push-receiver@backupserver1:backuppool1/push-received/workstation1/encrypted/USERDATA
      ```

   - To replicate only the newest existing snapshots (without replicating the intermediate snapshots), add the `--no-stream` option. Keep in mind that this will impact the retention policy.

## 5. Notes

- For `raw` replications, ensure you also maintain a backup of the encryption key from the source system.

- Configured permission sets require the `--no-sync-snap` replication option. Without this option, Syncoid creates semi-ephemeral snapshots at runtime, which would otherwise require the dangerous `destroy` permission.

- The initial replication must be performed to a non-existent dataset, for example `backuppool1/push-received/workstation1/encrypted/<dataset-name>` (`<dataset-name>` will be created automatically during the first replication).

- Local replication can be used to preseed the backup (for example [USB Replication](../replication-usb-syncoid)).

- You should customize the `autosnap`, `autoprune` and `monitor` policies to match your requirements.

- Because of a long-standing Syncoid bug, using `--no-sync-snap` with `--no-rollback` doesn’t work reliably with ZFS bookmarks. That’s why I’m opting to use ZFS holds for now.

- `encrypted-send-to-untrusted-receiver` use case: The sender transmits already encrypted data, and the receiver stores it without being able to decrypt it.

- `send-plain-encrypt-on-receive` use case: The sender transmits unencrypted data, and the receiver encrypts it when writing to the destination dataset.

- Please visit the [Sanoid wiki](https://github.com/jimsalterjrs/sanoid/wiki) for explanations of all Syncoid options and Sanoid configuration.

- This scenario was tested on Ubuntu Server 24.04.
