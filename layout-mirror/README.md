# ZFS Layout - Single Disk to Mirror Conversion

**The scenario:**

**The single-disk ZFS pool needs to be converted into a two-disk ZFS mirror.**

1. Attach the new disk.

2. Verify the configuration of the existing pool, especially the identifier of the current disk:

   ```bash
   zpool status <pool-name>
   ```

3. Find the identifier of the new disk.

   These tools can be helpful:

   ```bash
   lsblk
   sudo fdisk -l
   ls -la /dev/disk/by-id/
   ```

4. Remove all partitions from the new disk:

   ```bash
   sudo wipefs -a /dev/disk/by-id/<new-disk>
   ```

5. Add the new disk to the existing pool:

   NOTE: Use the `attach` command, not ~~`add`~~.

   ```bash
   sudo zpool attach <pool-name> /dev/disk/by-id/<current-disk> /dev/disk/by-id/<new-disk>
   ```

6. Monitor the status of the resilvering process:

   ```bash
   zpool status <pool-name>
   ```

## Notes

- This scenario was tested on Ubuntu Server 24.04.
