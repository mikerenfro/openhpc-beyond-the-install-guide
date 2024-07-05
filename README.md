# OpenHPC: Beyond the Install Guide

Materials for "OpenHPC: Beyond the Install Guide" half-day tutorial.
This is the `pearc24` branch for [PEARC24](https://pearc.acm.org/pearc24/).

Infrastruture preparation is largely adapted/copy-pasted from [Tim Middelkoop's ohpc-jetstream2 repo](https://github.com/MiddelkoopT/ohpc-jetstream2/), plus [Jetstream's CLI Overview](https://docs.jetstream-cloud.org/ui/cli/overview/) and following sections.

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

Running `vagrant up` from the top-level folder for this repository should create a Rocky 9 VM.
This VM will install `opentofu`, the Python OpenStack clients, Ansible, `xkcdpass`, `mtools` to build an iPXE disk image, `jq` to process JSON data, and all their dependencies.

If no file named `disk.img` exists in the `openstack-tofu` folder, the VM will create one.
Then, the VM will also copy the OpenRC file from the `openstack-tofu` folder into a startup folder for the `vagrant` user.
Finally, VM will create an ssh key for the `vagrant` user and include its public contents in the file `ssh_key.tf` in the `openstack-tofu` folder.

Once the VM is finished with these steps, you can log into it with `vagrant ssh` and manage things from there. Test that you can access OpenStack by running `openstack flavor list` and see a list of OpenStack instance types.

## OpenTofu initialization

First, `cd /vagrant/openstack-tofu` and run `./init.sh`.
This should initialize the project directory and use the iPXE image `disk.img` to create a new compute image type with an `e1000` network card.

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
3. Populate Ansible `host_vars` files with compute node names and MAC addreses, usernames, and passwords for each cluster.
4. Wait for every OpenHPC management node to respond to ssh connections.
5. Print the public IPv4 addresses for each OpenHPC management node.

## Notes for Tim's stuff

Installed [OpenTofu](https://opentofu.org) 1.7 via Homebrew (`brew install opentofu`)

Need to run `tofu init` in Tim's repo before doing anything else.

### Undeclared variables on first `tofu plan`

Running `tofu plan` for the first time results in lots of undeclared variables.
Tim alludes to this in his [README](https://github.com/MiddelkoopT/ohpc-jetstream2?tab=readme-ov-file#setup).

In order of appearance:

#### openstack_subnet_pool_shared_ipv6

Needed to create an IPv6-capable subnet with something like:

    % openstack subnet create --network renfro-test-network --ip-version 6 --ipv6-ra-mode slaac --ipv6-address-mode slaac --subnet-pool shared-default-ipv6 renfro-test-subnet
    +----------------------+-----------------------------------------------------------+
    | Field                | Value                                                     |
    +----------------------+-----------------------------------------------------------+
    | allocation_pools     | 2001:18e8:c02:110:6::2-2001:18e8:c02:110:6:ffff:ffff:ffff |
    | cidr                 | 2001:18e8:c02:110:6::/80                                  |
    | created_at           | 2024-06-29T22:24:54Z                                      |
    | description          |                                                           |
    | dns_nameservers      |                                                           |
    | dns_publish_fixed_ip | None                                                      |
    | enable_dhcp          | True                                                      |
    | gateway_ip           | 2001:18e8:c02:110:6::1                                    |
    | host_routes          |                                                           |
    | id                   | bae3792b-c944-487d-8088-39fff86e35c1                      |
    | ip_version           | 6                                                         |
    | ipv6_address_mode    | slaac                                                     |
    | ipv6_ra_mode         | slaac                                                     |
    | name                 | renfro-test-subnet                                        |
    | network_id           | 3e982dff-76ab-4be2-b09a-83eb2b679f37                      |
    | project_id           | e9fff7b433984cc4b60250f38d72fa1a                          |
    | revision_number      | 0                                                         |
    | segment_id           | None                                                      |
    | service_types        |                                                           |
    | subnetpool_id        | 58ad10b0-27be-46fd-ad9d-2c50630228b5                      |
    | tags                 |                                                           |
    | updated_at           | 2024-06-29T22:24:54Z                                      |
    +----------------------+-----------------------------------------------------------+

Use the `subnetpool_id` value, e.g. `58ad10b0-27be-46fd-ad9d-2c50630228b5`, in `local.tf` as:

    variable "openstack_subnet_pool_shared_ipv6" {
        type = string
        default = "58ad10b0-27be-46fd-ad9d-2c50630228b5"
    }

#### openstack_router_id

Need to make sure we have a router.

    % openstack router create renfro-test-router
    +-------------------------+--------------------------------------+
    | Field                   | Value                                |
    +-------------------------+--------------------------------------+
    | admin_state_up          | UP                                   |
    | availability_zone_hints |                                      |
    | availability_zones      |                                      |
    | created_at              | 2024-06-29T22:43:12Z                 |
    | description             |                                      |
    | enable_ndp_proxy        | False                                |
    | external_gateway_info   | null                                 |
    | flavor_id               | None                                 |
    | id                      | 31ac3020-3237-42ab-aa39-28ab970ff985 |
    | name                    | renfro-test-router                   |
    | project_id              | e9fff7b433984cc4b60250f38d72fa1a     |
    | revision_number         | 1                                    |
    | routes                  |                                      |
    | status                  | ACTIVE                               |
    | tags                    |                                      |
    | tenant_id               | e9fff7b433984cc4b60250f38d72fa1a     |
    | updated_at              | 2024-06-29T22:43:12Z                 |
    +-------------------------+--------------------------------------+
    % openstack router add subnet renfro-test-router renfro-test-subnet
    % openstack router set --external-gateway public renfro-test-router

Use the `id` value, e.g. `31ac3020-3237-42ab-aa39-28ab970ff985`, in `local.tf` as:

    variable "openstack_router_id" {
        type = string
        default = "31ac3020-3237-42ab-aa39-28ab970ff985"
    }

#### ssh_public_key

`ansible.cfg` lists `local.ini` as an inventory file. Contents in `openstack.tf` are derived from

    ## auto-generated
    [ohpc]
    head ansible_host=${openstack_networking_port_v2.ohpc-external.all_fixed_ips[1]} ansible_user=rocky arch=x86_64

    [ohpc:vars]
    sshkey=${var.ssh_public_key}

but it seems like `sshkey` is never used in playbooks? Going to comment out that line and remove the `ssh_public_key` entry for now.
