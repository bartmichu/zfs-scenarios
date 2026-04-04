# ZFS Scenarios

- **[ZFS Dataset Delegation - LXD](./delegation-lxd)**

  LXD container needs the ability to manage a ZFS dataset from LXD host, including creating child datasets, snapshots, and other related operations. The container should not be able to access other datasets in the parent pool.

- **[ZFS Layout - Single Disk to Mirror Conversion](./layout-mirror/)**

  The single-disk ZFS pool needs to be converted into a two-disk ZFS mirror.

- **[ZFS Layout - Single Disk or Mirror to Stripe Conversion](./layout-stripe/)**

  The single-disk or two-disk mirrored ZFS pool needs to be converted into a two-disk striped pool without redundancy.

- **[ZFS Replication - SSH Pull Replication with Syncoid](./replication-ssh-pull-syncoid)**

  Server contains a ZFS pool or datasets that needs to be backed up off-site to backup server. The backup should run in pull mode and use minimal privileges on both sides. The backup server should maintain its own independent retention policy. If the source pool is encrypted, the backup server must not require access to the decrypted data or the server's encryption keys. If the source pool is not encrypted, server-side encryption can be used instead.

- **[ZFS Replication - SSH Push Replication with Syncoid](./replication-ssh-push-syncoid)**

  Workstation contains a ZFS pool or datasets that needs to be backed up off-site to backup server. The backup should run in push mode and use minimal privileges on both sides. The backup server should maintain its own independent retention policy. If the source pool is encrypted, the backup server must not require access to the decrypted data or the workstation's encryption keys. If the source pool is not encrypted, server-side encryption can be used instead.

- **[ZFS Replication - USB backup with Sanoid and Syncoid](./replication-usb-syncoid)**

  The system contains a ZFS pool or datasets that needs to be backed up to an encrypted USB drive. Sanoid is responsible for creating and pruning snapshots, while Syncoid is responsible for replicating them. Snapshot creation and pruning on source filesystem are handled automatically, while replication and target filesystem snapshot pruning must be initiated manually. Both the encrypted-send-to-untrusted-receiver and send-plain-encrypt-on-receive use cases are supported.

- **[ZFS Replication - USB backup with zrepl](./replication-usb-zrepl)**

  The system contains a ZFS pool or datasets that needs to be backed up to an encrypted USB drive. zrepl is responsible for creating, replicating, and pruning snapshots. Snapshot creation and pruning are handled automatically, while replication must be initiated manually. Different retention policies should be applied: the source pool retains a shorter snapshot history to conserve local space, while the target USB pool maintains a longer archival history. Both the encrypted-send-to-untrusted-receiver and send-plain-encrypt-on-receive use cases are supported.

- **[Scripts](./scripts/)**

  Related utility scripts.

---

*Your data is your responsibility — please don't blame me if something goes wrong.*

---
