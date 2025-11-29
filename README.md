# ZFS Scenarios

- **[ZFS Replication - SSH Push Replication with Syncoid](./replication-ssh-push)**

  `Workstation1` contains a ZFS pool named `homepool` that needs to be backed up off-site to `replicaserver1`.

  The backup should run in push mode and use minimal privileges on both sides. The backup server should maintain its own independent retention policy. If source pool is encrypted, the server must not require access to the decrypted data or the workstation’s encryption keys. If it is not encrypted, server-side encryption may be used instead.
