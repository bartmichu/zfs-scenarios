# ZFS Replication - SSH Pull Replication with Syncoid

**Server contains a ZFS pool that needs to be backed up off-site to replication server.**

The backup should run in pull mode and use minimal privileges on both sides.

The replication server should maintain its own independent retention policy.

If source pool is encrypted, the replication server must not require access to the decrypted data or the server's encryption keys. If it is not encrypted, server-side encryption may be used instead.

## 1. Create a dedicated user account on the system with the source data pool (all commands are executed as `admin@server1`)

1. Create a dedicated user account:

   ```bash
   sudo adduser zfs-pull-sender
   ```

## 2. Prepare the system with the target data pool (all commands are executed as `admin@replicaserver1`)

1. Install required packages:

   ```bash
   sudo apt install zfsutils-linux sanoid mbuffer
   ```

2. Create a dedicated user account:

   ```bash
   sudo adduser zfs-pull-receiver
   ```

3. Create a key pair for the dedicated user and add the public key to the system with the source data pool:

   ```bash
   su - zfs-pull-receiver
   ssh-keygen -t ed25519 -f ~/.ssh/server1
   ssh-copy-id -i ~/.ssh/server1.pub zfs-pull-sender@server1
   exit
   ```

4. If necessary, create the target data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on backuppool /dev/disk/by-id/<disk-id>
   ```

5. Create the dataset structure.

   Create the parent dataset, unique for each client:

   ```bash
   sudo zfs create -p -o mountpoint=none -o compression=on backuppool/replicated-pull/server1
   ```

   Create encrypted dataset for replication without `raw` mode:

   ```bash
   sudo zfs create -o encryption=on -o keyformat=passphrase backuppool/replicated-pull/server1/encrypted
   ```

   Create unencrypted dataset for replication in `raw` mode:

   ```bash
   sudo zfs create backuppool/replicated-pull/server1/raw
   ```

6. Grant required permissions using ZFS permission delegation:

   ```bash
   sudo zfs allow -u zfs-pull-receiver create,mount,receive,hold,release backuppool/replicated-pull/server1/encrypted
   sudo zfs allow -u zfs-pull-receiver create,mount,receive,hold,release backuppool/replicated-pull/server1/raw
   ```

7. Configure Sanoid to delete old snapshots.

   Create the configuration file:

   ```bash
   sudo nano /etc/sanoid/sanoid.conf
   ```

   ```conf
   # replicaserver1

   [backuppool/replicated-pull/server1]
     use_template = pull_received
     recursive = yes

   [template_pull_received]
     autoprune = yes
     autosnap = no
     daily = 14
     frequent_period = 15
     frequently = 4
     hourly = 48
     monthly = 2
     yearly = 0
   ```

   ```bash
   sudo chmod 640 /etc/sanoid/sanoid.conf
   ```

   Reload Sanoid configuration:

   ```bash
   sudo systemctl restart sanoid.service
   ```

## 3. Prepare the system with the source data pool (all commands are executed as `admin@server1`)

1. Install required packages:

   ```bash
   sudo apt install zfsutils-linux sanoid mbuffer
   ```

2. Configure the SSH server:

   ```bash
   sudo nano /etc/ssh/sshd_config.d/zfs-pull-sender.conf
   ```

   ```conf
   # server1

   Match User zfs-pull-sender
     AllowUsers *@<replicaserver1-ip> #replace the IP address
     AuthenticationMethods publickey
     PasswordAuthentication no
     PermitTTY no
     X11Forwarding no
     PermitTunnel no
     GatewayPorts no
     Banner none
   ```

   ```bash
   sudo chmod 640 /etc/ssh/sshd_config.d/zfs-pull-sender.conf
   ```

   Test and apply the SSH server configuration:

   ```bash
   sudo sshd -t -f /etc/ssh/sshd_config.d/zfs-pull-sender.conf && sudo systemctl restart ssh.socket
   ```

3. Grant minimal required permissions using ZFS permission delegation:

   ```bash
   sudo zfs allow -u zfs-pull-sender bookmark,hold,send,release datapool
   ```

4. Configure Sanoid (for replication with the `--no-sync-snap` option, an additional snapshot creation mechanism is required).

   Create the configuration file:

   ```bash
   sudo nano /etc/sanoid/sanoid.conf
   ```

   ```conf
   # server1

   [datapool]
     use_template = standard
     recursive = yes

   [template_standard]
     autoprune = yes
     autosnap = yes
     daily = 7
     frequent_period = 15
     frequently = 4
     hourly = 24
     monthly = 1
     yearly = 0
   ```

   ```bash
   sudo chmod 640 /etc/sanoid/sanoid.conf
   ```

   Reload Sanoid configuration:

   ```bash
   sudo systemctl restart sanoid.service
   ```

## 4. Perform the replication

1. If necessary, load the encryption key on the target server (executed as admin@replicaserver1):

   ```bash
   zfs get keystatus -r backuppool/replicated-pull | grep encrypted
   sudo zfs load-key backuppool/replicated-pull/server1/encrypted
   ```

2. Initiate replication, preferably using a terminal multiplexer like `tmux` (all commands are executed as `zfs-pull-receiver@replicaserver1`).

   - For encrypted `datapool`: recursive replication of all already existing snapshots, using `raw` mode and `bookmark`, without using `hold`:

      ```bash
      syncoid --sendoptions=w --no-privilege-elevation --recursive --no-sync-snap --no-rollback --create-bookmark --sshkey ~/.ssh/server1 zfs-pull-sender@server1:datapool backuppool/replicated-pull/server1/raw/datapool
      ```

   - For server-side encryption: recursive replication of all already existing snapshots, using `bookmark`, without using `hold`:

      ```bash
      syncoid --no-privilege-elevation --recursive --no-sync-snap --no-rollback --create-bookmark --sshkey ~/.ssh/server1 zfs-pull-sender@server1:datapool backuppool/replicated-pull/server1/encrypted/datapool
      ```

   - To replicate only the newest existing snapshots (without replicating the intermediate snapshots), add the `--no-stream` option.

## 5. Notes

- For `raw` replications, ensure you also maintain a backup of the encryption key from the source system.

- Configured permission sets require the `--no-sync-snap` replication option. Without this option, Syncoid creates semi-ephemeral snapshots at runtime, which would otherwise require the dangerous `destroy` permission.

- The initial replication must be performed to a non-existent dataset, for example `backuppool/replicated-pull/server1/encrypted/<pool-name>` (`<pool-name>` will be created automatically during the first replication).

- Local replication can be used to preseed the backup (for example [USB Replication](../replication-usb-syncoid)).

- Please visit the [Sanoid wiki](https://github.com/jimsalterjrs/sanoid/wiki) for explanations of all Syncoid options and Sanoid configuration.

- This scenario was tested on Ubuntu Server 24.04.
