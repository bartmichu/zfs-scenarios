# ZFS Scenarios

- **[Local USB backups (zrepl)](./usb-backups-zrepl)**

  Local ZFS backup to an encrypted USB drive. The source system creates, replicates, and prunes snapshots using zrepl. Snapshot creation and pruning are automated, while replication is triggered manually. The source pool maintains a shorter retention policy to conserve space, while the destination USB backup pool maintains a longer archival retention policy. Both encrypted-send-to-untrusted-receiver and send-plain-encrypt-on-receive modes are supported.

- **[Off-site SSH pull backups (Sanoid + Syncoid)](./ssh-pull-backups-sanoid)**

  Off-site SSH pull backups. The source system (production) creates and manages its snapshots with Sanoid, which are periodically pulled to a destination backup server using Syncoid. The backup server maintains its own independent retention policy with Sanoid. If the source pool is encrypted, the backup server does not need access to decrypted data or the production's encryption keys (encrypted-send-to-untrusted-receiver). Alternatively, destination-side encryption can be used (send-plain-encrypt-on-receive). Dedicated user accounts with only a minimal set of privileges are used on both sides.

- **[Off-site SSH push backups (Sanoid + Syncoid)](./ssh-push-backups-sanoid)**

  Off-site SSH push backups. The source system (workstation) creates and manages its snapshots with Sanoid, which are periodically pushed to a destination backup server using Syncoid. The backup server maintains its own independent retention policy with Sanoid. If the source pool is encrypted, the backup server does not need access to decrypted data or the workstation's encryption keys (encrypted-send-to-untrusted-receiver). Alternatively, destination-side encryption can be used (send-plain-encrypt-on-receive). Dedicated user accounts with only a minimal set of privileges are used on both sides.

- **[ZFS Dataset Delegation - LXD](./delegation-lxd)**

  ZFS dataset delegation from an LXD host to a container. The container can manage a specific dataset - including creating child datasets, snapshots, and performing related operations - while remaining restricted from accessing other datasets in the parent pool.

- **[ZFS Layout - Single Disk to Mirror Conversion](./layout-mirror/)**

  The single-disk ZFS pool needs to be converted into a two-disk ZFS mirror.

- **[ZFS Layout - Single Disk or Mirror to Stripe Conversion](./layout-stripe/)**

  The single-disk or two-disk mirrored ZFS pool needs to be converted into a two-disk striped pool without redundancy.

- **[Scripts](./scripts/)**

  Related utility scripts.

---

*Your data is your responsibility — please don't blame me if something goes wrong.*

---
