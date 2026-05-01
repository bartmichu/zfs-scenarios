# ZFS Dataset Delegation - LXD

**ZFS dataset delegation from an LXD host to a container. The container can manage a specific dataset - including creating child datasets, snapshots, and performing related operations - while remaining restricted from accessing other datasets in the parent pool.**

## 1. Prepare the LXD container (all commands are executed as admin@lxdcontainer)

1. Install required packages:

   ```bash
   sudo apt install zfsutils-linux
   ```

## 2. Prepare the ZFS pool on the LXD host (all commands are executed as admin@lxdhost)

1. If necessary, create the data pool:

   ```bash
   sudo zpool create -O mountpoint=none -O compression=on datapool /dev/disk/by-id/<disk-id>
   ```

2. Create the parent dataset:

   ```bash
   sudo zfs create -p datapool/delegated/lxdtank
   ```

## 3. Configure the LXD storage (all commands are executed as admin@lxdhost)

1. Create an LXD pool:

   ```bash
   sudo lxc storage create lxdtank zfs source=datapool/delegated/lxdtank
   ```

   Create LXD volume:

   ```bash
   sudo lxc storage volume create lxdtank lxdvolume
   ```

2. Stop the container that the volume will be attached to:

   ```bash
   sudo lxc stop lxdcontainer
   ```

3. Attach the volume to the container:

   ```bash
   sudo lxc storage volume attach lxdtank lxdvolume lxdcontainer disk-device-1 /srv/lxdvolume
   ```

4. Configure volume delegation:

   ```bash
   sudo lxc storage volume set lxdtank custom/lxdvolume zfs.delegate=true
   ```

5. Start the container to which the volume is attached:

   ```bash
   sudo lxc start lxdcontainer
   ```

## 4. Verify that the delegation is configured correctly (all commands are executed as admin@lxdcontainer)

1. List pools and datasets:

   ```bash
   zpool list
   zfs list
   ```

## 5. Notes

- You can use the LXD UI as well - it's well organized, and all sections should be easy to find.

- Delegating ZFS permissions for a host-delegated dataset from within the container does not work correctly due to UID mapping.

- This scenario was tested on Ubuntu Server 26.04 and LXD 5.21/stable.
