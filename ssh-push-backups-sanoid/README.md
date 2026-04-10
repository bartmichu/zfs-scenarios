# Off-site SSH push backups (Sanoid + Syncoid)

**Off-site SSH push backups. The source system (workstation) creates and manages its snapshots with Sanoid, which are periodically pushed to a destination backup server using Syncoid. The backup server maintains its own independent retention policy with Sanoid. If the source pool is encrypted, the backup server does not need access to decrypted data or the workstation's encryption keys (encrypted-send-to-untrusted-receiver). Alternatively, destination-side encryption can be used (send-plain-encrypt-on-receive). Dedicated user accounts with only a minimal set of privileges are used on both sides.**

## 1. Prepare the system with the destination data pool, part 1/2 (all commands are executed as `admin@backup1`)

1. Install required packages:

   ```bash
   sudo apt install zfsutils-linux mbuffer sanoid
   ```

2. Create a dedicated user account:

   ```bash
   sudo adduser zfs-push-receiver
   ```

3. If necessary, create the destination data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on backuppool1 /dev/disk/by-id/<disk-id>
   ```

4. Create the dataset structure.

   Create the parent dataset, unique for each source system (`workstation1`, `workstation2` etc.):

   ```bash
   sudo zfs create -p backuppool1/push-received/workstation1
   ```

   Create an unencrypted dataset for encrypted-send-to-untrusted-receiver replication (`raw` mode), used with encrypted source datasets when the sender transmits already encrypted data and the receiver stores it without being able to decrypt it:

   ```bash
   sudo zfs create backuppool1/push-received/workstation1/raw
   ```

   Create an encrypted dataset for send-plain-encrypt-on-receive replication, used with encrypted or unencrypted source datasets when the sender transmits unencrypted data and the receiver encrypts it when writing to the destination dataset (the destination has the encryption key):

   ```bash
   sudo zfs create -o encryption=on -o keyformat=passphrase backuppool1/push-received/workstation1/encrypted
   ```

5. Configure Sanoid to automatically prune snapshots.

   Edit the configuration file:

   ```bash
   sudo nano /etc/sanoid/sanoid.conf
   ```

   ```conf
   # backup1

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
     daily = 30
     #daily_crit = 36h
     #daily_warn = 25h
     frequent_period = 15
     frequently = 4
     #frequently_crit = 0
     #frequently_warn = 0
     hourly = 48
     #hourly_crit = 24h
     #hourly_warn = 2h
     #monitor = yes
     monthly = 6
     #monthly_crit = 36d
     #monthly_warn = 32d
     weekly = 8
     #weekly_crit = 12d
     #weekly_warn = 8d
     yearly = 0
     #yearly_crit = 0
     #yearly_warn = 0
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

## 2. Prepare the system with the source data pool (all commands are executed as `admin@workstation1`)

1. Install required packages:

   ```bash
   sudo apt install zfsutils-linux mbuffer sanoid
   ```

2. Create a dedicated user account:

   ```bash
   sudo adduser zfs-push-sender
   ```

3. Create a key pair for the dedicated user and add the public key to the system with the destination data pool:

   ```bash
   su - zfs-push-sender
   ssh-keygen -t ed25519 -f ~/.ssh/backup1 -C "zfs-push-sender@workstation1"
   ssh-copy-id -i ~/.ssh/backup1.pub zfs-push-receiver@backup1
   exit
   ```

4. Grant minimal required permissions using ZFS permission delegation.

   In the case of replication using only encrypted-send-to-untrusted-receiver, and when your ZFS version supports the `send:raw` permission (`raw` mode):

   ```bash
   sudo zfs allow -u zfs-push-sender bookmark,hold,release,send:raw rpool/USERDATA
   ```

   Otherwise:

   ```bash
   sudo zfs allow -u zfs-push-sender bookmark,hold,release,send rpool/USERDATA
   ```

5. Configure Sanoid to automatically create and prune snapshots.

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

## 3. Prepare the system with the destination data pool, part 2/2 (all commands are executed as `admin@backup1`)

1. Configure the SSH server:

   ```bash
   sudo nano /etc/ssh/sshd_config.d/zfs-push-receiver.conf
   ```

   ```conf
   #backup1

   Match User zfs-push-receiver
     AllowAgentForwarding no
     AllowTcpForwarding no
     AllowUsers *@127.0.0.1 # Replace with the actual IP address of workstation1 or use * to allow any host
     AuthenticationMethods publickey
     Banner none
     GatewayPorts no
     LogLevel VERBOSE
     MaxAuthTries 1
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

2. Restrict an authorized SSH key.

   ```bash
   sudo nano /home/zfs-push-receiver/.ssh/authorized_keys
   ```

   Find the `zfs-push-sender@workstation1` key and modify the line so it looks something like this (replace `127.0.0.1` with the actual IP address of workstation1 or use * to allow any host):

   ```config
   from="127.0.0.1",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... zfs-push-sender@workstation1
   ```

3. Grant minimal required permissions using ZFS permission delegation.

   ```bash
   sudo zfs allow -u zfs-push-receiver mount,create,hold,receive,release backuppool1/push-received/workstation1/encrypted
   sudo zfs allow -u zfs-push-receiver mount,create,hold,receive,release backuppool1/push-received/workstation1/raw
   ```

## 4. Perform the replication

1. If necessary (send-plain-encrypt-on-receive), load the encryption key on the destination server (executed as `admin@backup1`):

   ```bash
   zfs get keystatus -r backuppool1/push-received | grep encrypted
   sudo zfs load-key backuppool1/push-received/workstation1/encrypted
   ```

2. Initiate replication, preferably using a terminal multiplexer like `tmux` (all commands are executed as `zfs-push-sender@workstation1`).

   - For encrypted-send-to-untrusted-receiver use case (`raw` mode):

      ```bash
      syncoid --sendoptions='-w' --recvoptions='-u -x canmount' --no-privilege-elevation --recursive --no-sync-snap --no-rollback --no-clone-handling --create-bookmark --use-hold --include-snaps='^autosnap_' --sshkey ~/.ssh/backup1 rpool/USERDATA zfs-push-receiver@backup1:backuppool1/push-received/workstation1/raw/USERDATA
      ```

   - For send-plain-encrypt-on-receive use case:

      ```bash
      syncoid --recvoptions='-u -x canmount' --no-privilege-elevation --recursive --no-sync-snap --no-rollback --no-clone-handling --create-bookmark --use-hold --include-snaps='^autosnap_' --sshkey ~/.ssh/backup1 rpool/USERDATA zfs-push-receiver@backup1:backuppool1/push-received/workstation1/encrypted/USERDATA
      ```

## 5. Notes

- Test the restoration procedure.

- For `raw` replications (encrypted-send-to-untrusted-receiver), ensure that you also maintain a backup of the encryption key from the source system; otherwise, these backups will be worthless.

- The initial replication must be performed to a non-existent dataset, for example `backuppool1/push-received/workstation1/encrypted/<dataset-name>` (`<dataset-name>` will be created automatically during the first replication).

- Local USB replication can be used to preseed the backup.

- You should customize the `autosnap`, `autoprune` and `monitor` policies to match your requirements. On the backup server, the pruning period must be longer than on the production system, and the `autosnap` option must be set to `no`.

- Configured permission sets require the `--no-sync-snap` replication option. Without this option, Syncoid creates semi-ephemeral snapshots at runtime, which would otherwise require the dangerous `destroy` permission.

- Because of a Syncoid bug, using `--no-sync-snap` with `--no-rollback` doesn't work reliably with ZFS bookmarks [#625](<https://github.com/jimsalterjrs/sanoid/pull/625>).

- The `send:raw` permission is available in `zfs-2.4.1`; use the less restrictive `send` permission on older ZFS versions.

- Please visit the [Sanoid wiki](https://github.com/jimsalterjrs/sanoid/wiki) for explanations of all Syncoid options and Sanoid configuration.

- This scenario was tested on Ubuntu Server 26.04 with Sanoid 2.3.0.

## 6. The missing parts

- Implement `ForceCommand` to properly restrict the `zfs-push-receiver` account.

- Configure a systemd service or a cron job to automate backups.

- Set up monitoring using Nagios or Zabbix.
