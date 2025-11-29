# ZFS Scenarios

- **[ZFS Dataset Delegation - LXD](./delegation-lxd)**

  LXD container needs the ability to manage a ZFS dataset from LXD host, including creating child datasets, snapshots, and other related operations.

  The container should not be able to access other datasets in the parent pool.

- **[ZFS Replication - SSH Push Replication with Syncoid](./replication-ssh-push)**

  Workstation contains a ZFS pool that needs to be backed up off-site to replication server.

  The backup should run in push mode and use minimal privileges on both sides. The backup server should maintain its own independent retention policy. If source pool is encrypted, the server must not require access to the decrypted data or the workstation’s encryption keys. If it is not encrypted, server-side encryption may be used instead.

---

*Your data is your responsibility — please don't blame me if something goes wrong.*

---
