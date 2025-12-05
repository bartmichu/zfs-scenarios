# ZFS Layout - Single Disk or Mirror to Stripe Conversion

**The scenario:**

**The single-disk or two-disk mirrored ZFS pool needs to be converted into a two-disk striped pool without redundancy.**

1. Verify the identifier of the secondary disk.

   a) If the pool contains only one disk:

      - Attach the new disk.

      - Find the identifier of the new disk. These tools can be helpful:

        ```bash
        lsblk
        sudo fdisk -l
        ls -la /dev/disk/by-id/
        ```

   b) If the pool is configured as a mirror:

      - Verify the configuration of the existing pool, especially the identifier of the current disks:

        ```bash
        zpool status <pool-name>
        ```

      - Detach the redundant disk from the pool:

        ```bash
        sudo zpool detach <pool-name> <secondary-disk>
        ```

2. Remove all partitions from the secondary disk:

   ```bash
   sudo wipefs -a /dev/disk/by-id/<secondary-disk>
   ```

3. If needed, enable the `autoexpand` option for the pool:

   ```bash
   zpool get autoexpand <pool-name>
   sudo zpool set autoexpand=on <pool-name>
   ```

4. Add the new disk to the existing pool

   NOTE: Use the `add` command, not ~~`attach`~~.

   ```bash
   sudo zpool add <pool-name> /dev/disk/by-id/<secondary-disk>
   ```

## Notes

- This scenario was tested on Ubuntu Server 24.04.
