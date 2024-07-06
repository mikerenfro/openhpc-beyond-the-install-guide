# OpenHPC: Beyond the Install Guide

Materials for "OpenHPC: Beyond the Install Guide" half-day tutorial.
This is the `pearc24` branch for [PEARC24](https://pearc.acm.org/pearc24/).

Infrastructure preparation is largely adapted/copy-pasted from [Tim Middelkoop's ohpc-jetstream2 repo](https://github.com/MiddelkoopT/ohpc-jetstream2/), plus [Jetstream's CLI Overview](https://docs.jetstream-cloud.org/ui/cli/overview/) and following sections.

The goal of this repository is to let instructors or self-learners to construct one or more OpenHPC 3.x virtual environments, and for those environments to be as close as possible to the defaults from the OpenHPC installation guide.

These environments will be using Rocky 9 x86_64, Warewulf 3, and Slurm.

# Prerequisites to set this up yourself

1. A copy of this repository.
2. [Vagrant](https://www.vagrantup.com) on x86-64 with one of the following desktop hypervisors: VirtualBox, VMware desktop hypervisors, or Parallels. Might also work with Apple Silicon systems with VMware desktop hypervisors, but this is currently untested.
3. OpenStack CLI and API access (only tested with Jetstream2).
4. An OpenStack RC file for your OpenStack (e.g., generated from [Setting up application credentials and openrc.sh for the Jetstream2 CLI](https://docs.jetstream-cloud.org/ui/cli/auth/#setting-up-application-credentials-and-openrcsh-for-the-jetstream2-cli)).

# Repository structure

1. `README.md` is what you're reading now.
2. `Vagrantfile` provides settings for a consistent environment used to create the Jetstream2 infrastructure for the workshop.
3. `reference` contains an unmodified copy of OpenHPC's `recipe.sh` and `input.local` files from Appendix A of [OpenHPC (v3.1) Cluster Building Recipes, Rocky 9.3 Base OS, Warewulf/SLURM Edition for Linux (x86 64)](https://github.com/openhpc/ohpc/releases/download/v3.1.GA/Install_guide-Rocky9-Warewulf-SLURM-3.1-x86_64.pdf).
4. `repos` contains third-party `yum` repositories for the Vagrant VM (currently only for `opentofu`).
5. `openstack-tofu` contains Terraform/OpenTofu configuration files to build the HPC cluster structure for the instructor and the students, plus shell scripts to exchange data between the configuration output and Ansible.
6. `ansible` contains Ansible playbooks, inventories, and host variables used to complete configuration of the HPC cluster installation for the instructor and the students.
7. `.vagrant` will show up after you build the Vagrant VM. Its contents are all ignored.
8. `.gitignore` controls which files are ignored by `git`. Probably no reason to modify it.

# Setting up the workshop

## OpenRC file

Copy the OpenRC file you got from Jetstream into the `openstack-tofu` folder.
Make sure the OpenRC file is named to match the wildcard `app-cred-*-openrc.sh`.
You should only have one OpenRC file in this folder.

## Vagrant VM

Run `vagrant up` from the top-level folder for this repository; this should create a Rocky 9 VM.
The VM will install `opentofu`, the Python OpenStack clients, Ansible, `xkcdpass`, `mtools` to build an iPXE disk image, `jq` to process JSON data, and all their dependencies.

If no file named `disk.img` exists in the `openstack-tofu` folder, the VM will create one.
Then, the VM will also copy the OpenRC file from the `openstack-tofu` folder into a startup folder for the `vagrant` user.
Also, the VM will ensure that the `vagrant` user does not inherit any `SSH_AUTH_SOCK` variables from the outside environment, as this can interfere with SSH connections to the management nodes. 
Finally, VM will create an ssh key for the `vagrant` user and include its public contents in the file `ssh_key.tf` in the `openstack-tofu` folder.

Once the VM is finished with these steps, you can log into it with `vagrant ssh` and manage things from there. Test that you can access OpenStack by running `openstack flavor list` and see a list of OpenStack instance types.

## OpenTofu initialization

First, `cd /vagrant/openstack-tofu` and run `./init.sh`.
This should initialize the project directory, and if no compute image named `efi-ipxe` exists in your OpenStack project, it will create a new compute image type with an `e1000` network card using `disk.img`.

## OpenTofu settings

Next, create a file `local.tf` in the `/vagrant/openstack-tofu` folder. It should contain the following variables:

```
variable "outside_ip_range" {
    type = string
    default = "0.0.0.0/0"
}

variable "openstack_public_network_id" {
    type = string
    default = "3fe22c05-6206-4db2-9a13-44f04b6796e6"
    # no need to change this for any Jetstream2 allocation, looks like.
}

variable "n_students" {
    type = number
    default = 0
}

variable "nodes_per_cluster" {
    type = number
    default = 1
}
```

1. `outside_ip_range` defines which IPs are allowed ssh and ping access to the HPC management nodes.
2. `openstack_public_network_id` contains the ID of the "public" network at the edge of your OpenStack environment. On Jetstream2, it can be found by clicking the "public" name at [the Project / Network / Networks](https://js2.jetstream-cloud.org/project/networks/) entry for your project allocation. As I had the same network ID on two different projects on Jetstream2, this may be a constant value for everyone.
3. `n_students` defines how many student clusters to set up (not including the cluster always set up for the instructors).
4. `nodes_per_cluster` defines how many compute nodes to set up for each cluster.

You may need to increase your project allocation if adding `(n_students+1)*nodes_per_cluster` compute instances would exceed your compute instance limit.

## OpenTofu resource creation

Next, run `./create.sh` in the `/vagrant/openstack-tofu` folder.
This script will create:

1. A router defining the boundary separating the OpenHPC-related resources and the outside world.
2. An external network, subnet, and security group connecting all OpenHPC management nodes to the router.
3. `n_students+1` OpenHPC management nodes named `sms-0` through `sms-N`, running Rocky 9 with 2 cores, 6 GB RAM, 20 GB disk space, and a public IPv4 address.
4. `n_students+1` separate internal networks and subnets to connect compute nodes to the OpenHPC management nodes. These have little to no network security enabled, similar to a purely internal HPC network.
5. `(n_students+1)*(nodes_per_cluster)` OpenHPC compute nodes named `clusterM-nodeN`, each connected to the correct internal network.
6. `n_students+1` host entries in `~vagrant/.ssh/config`, which enables `ssh username@sms-N` to automatically connect to the correct manaegment node.

Additionally, the `create.sh` script will also:

1. Retrieve the public IPv4 addresses for each OpenHPC management node.
2. Remove any ssh host keys for those addresses stored in `~vagrant/.ssh/known_hosts`.
3. Populate Ansible `host_vars` files with compute node names and MAC addreses, usernames, and passwords for each cluster. You can adjust the number of user accounts created by changing the `USERS_PER_HOST` value in `create.sh`.
4. Wait for every OpenHPC management node to respond to ssh connections.
5. Print the public IPv4 addresses for each OpenHPC management node.

## Ansible

To finish configuring the clusters,  `cd /vagrant/ansible`. The Ansible folder contains 7 main playbooks generally corresponding to sections of [OpenHPC (v3.1) Cluster Building Recipes, Rocky 9.3 Base OS, Warewulf/SLURM Edition for Linux (x86 64)](https://github.com/openhpc/ohpc/releases/download/v3.1.GA/Install_guide-Rocky9-Warewulf-SLURM-3.1-x86_64.pdf):

1. 0-undocumented-prereqs-unrelated-settings.yaml
2. 2-install-base-os.yaml
3. 3-install-openhpc-components.yaml
4. a0-installation-template.yaml
5. a1-run-recipe.yaml
6. a1-run-recipe.yaml
7. z-post-recipe.yaml

Run these manually one at a time in order, or in a for loop like `for p in [023az]*.yaml; do ansible-playbook $p; done`.

### `0-undocumented-prereqs-unrelated-settings.yaml`

Installs any programs needed for the default OpenHPC configuration files to work, particularly, the `s-nail` program for `MailProg=/bin/mail` in `/etc/slurm/slurm.conf`.

Also configures a few more settings applicable to a multi-student workshop environment, but not necessarily required in every case:

1. Adding the `user1`, ..., `userN` accounts, with membership in group `wheel`.
2. Ensuring members of group `wheel` have password-less `sudo` access.
3. Enabling password authentication for ssh connections and reloading the `sshd` service.

### `2-install-base-os.yaml`

As the default Rocky 9 Jetstream images have a workable base operating system installed, completing section 2 of the installation guide only requires:

1. Adding the management system's hostname and internal IP to /etc/hosts.
2. Disabling SELinux.
3. Setting the timezone to `America/New_York`.
   
Though stopping and disabling `firewalld` is part of section 2, it's already handled in the `recipe.sh` script from Appendix A, so we omit it here.

### `3-install-openhpc-components.yaml`

Since we'll be using the `recipe.sh` script to perform the installation, we skip over most of the steps in section 3.
Instead we:

1. Install the OpenHPC repository release file.
2. Enable the CodeReady Builder repository if needed.
3. Install the `docs-ohpc` package to get a copy of `recipe.sh` and `input.local`.

### `a0-installation-template.yaml`

This playbook makes copies of `recipe.sh` and `input.local`, and modifies them to either match the virtual environment, or to ensure more things are running correctly when the students first connect.
This includes:

#### `input.local`

1. Setting `provision_wait=1` to spend less time waiting for remote node power-cycling with IPMI, since that's not supported in Jetstream2.
2. Setting `num_computes` to the number of compute nodes in each cluster.
3. Replacing MAC addresses for the compute nodes.
4. Changing the `slurm_node_config` and `update_slurm_nodeconfig` variables to ensure `slurm.conf` has the correct values for the OpenStack instance type.
5. Setting `sms_name` to the correct hostname of the management node (i.e., `sms-N`).

#### `recipe.sh`

1. Changing the `CHROOT` path from `/opt/ohpc/admin/images/rocky9.3` to `/opt/ohpc/admin/images/rocky9.4`.
2. Ensuring that the `slurmd` and `munge` services are enabled in the chroot.
3. Removing unneeded `pdsh` commands.
4. Replacing `echo` commands with idempotent `ansible.builtin.lineinfile` tasks for both `/etc/exports` and `/etc/chrony.conf`.

### `a1-run-recipe.yaml`

This playbook simply runs the copy of `recipe.sh` with the environment variable `OHPC_INPUT_LOCAL` pointing to the modified copy of `input.local`.
This will probably take around 10 minutes to run, and multiple management nodes can run the script simultaneously.

### `z-post-recipe.yaml`

This playbook fixes a few things that can only be done after `recipe.sh` has run:

1. Setting the timezone in the chroot to `America/New_York` and rebuilding the chroot.
2. Removing duplicate `ReturnToService` lines from `/etc/slurm/slurm.conf` (will be unnecessary after an OpenHPC release including [PR 1994](https://github.com/openhpc/ohpc/pull/1994)) is announced).
3. Creating `/var/log/slurmctld.log` with correct ownership and permissions.
4. Storing host ssh keys from the compute nodes in the management node's `/etc/ssh/ssh_known_hosts` to eliminate warnings on first ssh connections to the compute nodes.
5. Rebooting the compute nodes to apply the updated system image from item 1.

# Testing the workshop environment

By default, each OpenHPC management node has three user accounts defined:

1. `rocky`, which allows logins from the `vagrant` account's ssh key.
2. `user1` and `user2`, which have the same password, and which allow logins from any user with the password.

The passwords for each cluster's `user1` and `user2` account are stored in the `/vagrant/ansible/user-passwords.txt` file.
The passwords for cluster `N` can be found on line `N+1` of that file (i.e., if the `vagrant` user runs `ssh user2@sms-4`, the password will be on line 5 of the `user-passwords.txt` file.)
All other users can ssh to the OpenHPC management nodes by IP address. Each management node's IP address can be found in the `/vagrant/ansible/local.ini` file.