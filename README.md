# OpenHPC: Beyond the Install Guide

Materials for "OpenHPC: Beyond the Install Guide" half-day tutorial.
This is the `pearc24` branch for [PEARC24](https://pearc.acm.org/pearc24/).

## Vagrant VM

Used to create `disk.img` for the `openstack image create` command from [Tim's Jetstream2 docs](https://github.com/MiddelkoopT/ohpc-jetstream2/tree/main?tab=readme-ov-file#setup).

Uses [Vagrant bento/rockylinux-9](https://app.vagrantup.com/bento/boxes/rockylinux-9), so should run on any x86-64 system with VirtualBox, VMware desktop hypervisors, or Parallels.

`vagrant up` should result in a `disk.img` file in the top-level folder for this repository.
Follow up with `vagrant -f destroy` to delete the VM afterwards.
