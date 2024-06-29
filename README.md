# OpenHPC: Beyond the Install Guide

Materials for "OpenHPC: Beyond the Install Guide" half-day tutorial.
This is the `pearc24` branch for [PEARC24](https://pearc.acm.org/pearc24/).

## Vagrant VM

Used to create `disk.img` for the `openstack image create` command from [Tim's Jetstream2 docs](https://github.com/MiddelkoopT/ohpc-jetstream2/tree/main?tab=readme-ov-file#setup), and also for OpenStack, OpenTofu, and Ansible usage to configure the VMs for the workshop.

Uses [Vagrant bento/rockylinux-9](https://app.vagrantup.com/bento/boxes/rockylinux-9), so should run on any x86-64 system with VirtualBox, VMware desktop hypervisors, or Parallels.

`vagrant up` should result in a `disk.img` file in the top-level folder for this repository.
Follow up with `vagrant -f destroy` to delete the VM afterwards.

Once disk.img is made, can run

    openstack image create --disk-format raw --file disk.img --property hw_firmware_type='uefi' --property hw_scsi_model='virtio-scsi' --property hw_machine_type=q35 efi-ipxe

to upload the image to the Jetstream2 allocation in use.

## Notes for Tim's stuff

Installed [OpenTofu](https://opentofu.org) 1.7 via Homebrew (`brew install opentofu`)/

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
