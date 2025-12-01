# ZFS Dataset Delegation - LXD

**LXD container needs the ability to manage a ZFS dataset from LXD host, including creating child datasets, snapshots, and other related operations.**

The container should not be able to access other datasets in the parent pool.

## 1. Prepare the ZFS pool on the LXD host (all commands are executed as admin@lxdhost)

1. If necessary, create the data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on datapool /dev/disk/by-id/<disk-id>
   ```

2. Create the parent dataset:

   ```bash
   sudo zfs create -p -o mountpoint=none -o compression=on datapool/delegated/lxdtank
   ```

## 2. Configure the LXD storage (all commands are executed as admin@lxdhost)

1. Create an LXD pool:

   ```bash
   sudo lxc storage create lxdtank zfs source=datapool/delegated/lxdtank
   ```

   Create LXD volume:

   ```bash
   sudo lxc storage volume create lxdtank containertank
   ```

2. Stop the container that the volume will be attached to:

   ```bash
   sudo lxc stop lxdcontainer
   ```

3. Attach the volume to the container:

   ```bash
   sudo lxc storage volume attach lxdtank containertank lxdcontainer disk-device-1 /srv/containertank
   ```

4. Configure volume delegation:

   ```bash
   sudo lxc storage volume set lxdtank custom/containertank zfs.delegate=true
   ```

5. Start the container to which the volume is attached:

   ```bash
   sudo lxc start lxdcontainer
   ```

## 3. Prepare the LXD container (all commands are executed as admin@lxdcontainer)

1. Install required packages:

   ```bash
   sudo apt install zfsutils-linux
   ```

2. Verify that the delegation is configured correctly:

   ```bash
   zfs list
   ```

## 4. Notes

- You can use the LXD UI as well - it’s well organized, and all sections should be easy to find.

- ZFS permission delegation does not work correctly on a volume delegated by LXD.

- This scenario was tested on Ubuntu Server 24.04 and LXD 5.21/stable.
