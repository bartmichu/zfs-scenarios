# ZFS Dataset Delegation - LXD

**LXD container needs the ability to manage a ZFS dataset from LXD host, including creating child datasets, snapshots, and other related operations.**

The container should not be able to access other datasets in the parent pool.

## 1. Prepare the ZFS pool on the LXD host (all commands are executed as admin@lxdhost)

1. If necessary, create the data pool:

   ```shell
   sudo zpool create -O mountpoint=none -O compression=on datapool /dev/disk/by-id/<disk-id>
   ```

2. Create the parent dataset:

   ```shell
   sudo zfs create -p -o mountpoint=none -o compression=on datapool/delegated/lxdtank
   ```

## 2. Configure the LXD storage (all commands are executed as admin@lxdhost)

1. Create an LXD pool:

   ```shell
   sudo lxc storage create lxdtank zfs source=datapool/delegated/lxdtank
   ```

   Create LXD volumes:

   ```shell
   sudo lxc storage volume create lxdtank containertank
   ```

2. Stop the container that the volume will be attached to:

   ```shell
   sudo lxc stop lxdcontainer
   ```

3. Attach the volumes to the container:

   ```shell
   sudo lxc storage volume attach lxdtank containertank lxdcontainer disk-device-1 /srv/containertank
   ```

4. Configure volume delegation:

   ```shell
   sudo lxc storage volume set lxdtank custom/containertank zfs.delegate=true
   ```

5. Start the container to which the volume is attached:

   ```shell
   sudo lxc start lxdcontainer
   ```

## 3. Prepare the LXD container (all commands are executed as admin@lxdcontainer)

1. Install required packages:

   ```shell
   sudo apt install zfsutils-linux
   ```

2. Verify that the delegation is configured correctly:

   ```shell
   zfs list
   ```

## 4. Notes

- You can use the LXD UI as well - it’s well organized, and all sections should be easy to find.

- ZFS permission delegation does not work correctly on a volume delegated by LXD.

- This scenario was tested on Ubuntu Server 24.04 and LXD 5.21/stable.
