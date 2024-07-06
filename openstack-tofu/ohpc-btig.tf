resource "openstack_networking_network_v2" "ohpc-btig-internal-network" {
  count          = var.n_students+1
  name           = "ohpc-btig-internal-network-${count.index}"
  admin_state_up = "true"
}
resource "openstack_networking_subnet_v2" "ohpc-btig-internal-subnet" {
  count       = var.n_students+1
  network_id  = openstack_networking_network_v2.ohpc-btig-internal-network[count.index].id
  name        = "ohpc-btig-internal-subnet-${count.index}"
  cidr        = "172.16.0.0/16"
  enable_dhcp = false
}

## https://docs.jetstream-cloud.org/ui/cli/launch/ and
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_v2
resource "openstack_networking_floatingip_v2" "ohpc-btig-floating-ip-sms" {
  count = var.n_students+1
  pool  = "public"
}
resource "openstack_networking_port_v2" "ohpc-btig-port-external-sms" {
  count          = var.n_students+1
  name           = "ohpc-btig-port-external-sms-${count.index}"
  admin_state_up = "true"
  network_id     = openstack_networking_network_v2.ohpc-btig-external-network.id

  security_group_ids = [openstack_networking_secgroup_v2.ohpc-btig-ssh-icmp.id]
  fixed_ip {
      subnet_id  = openstack_networking_subnet_v2.ohpc-btig-external-subnet.id
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-btig-external-subnet.cidr, 256+count.index)
  }
}
resource "openstack_networking_floatingip_associate_v2" "ohpc-btig-floating-ip-associate-sms" {
  count       = var.n_students+1
  floating_ip = openstack_networking_floatingip_v2.ohpc-btig-floating-ip-sms[count.index].address
  port_id     = openstack_networking_port_v2.ohpc-btig-port-external-sms[count.index].id
}
resource "openstack_networking_port_v2" "ohpc-btig-port-internal-sms" {
  name           = "ohpc-btig-port-internal-sms-${count.index}"
  count          = var.n_students+1
  admin_state_up = "true"
  network_id = openstack_networking_network_v2.ohpc-btig-internal-network[count.index].id

  # https://access.redhat.com/solutions/2428301
  port_security_enabled = false
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.ohpc-btig-internal-subnet[count.index].id
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-btig-internal-subnet[count.index].cidr, 1)
  }
}
resource "openstack_compute_instance_v2" "ohpc-btig-sms" {
  count = var.n_students+1
  name = "sms-${count.index}"
  flavor_name = "m3.small"
  image_name = "Featured-RockyLinux9"
  key_pair = "ohpc-btig-keypair"
  network {
    port = openstack_networking_port_v2.ohpc-btig-port-external-sms[count.index].id
  }
  network {
    port = openstack_networking_port_v2.ohpc-btig-port-internal-sms[count.index].id
  }
  user_data = <<-EOF
    #!/bin/bash
    passwd -d root
    rm -v /root/.ssh/authorized_keys
    EOF
}

locals {
  compute_nodes = setproduct(range(var.n_students+1), range(var.nodes_per_cluster))
}

resource "openstack_compute_instance_v2" "node" {
  for_each = {
    for node in local.compute_nodes : "cluster${node[0]}-node${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  name = "cluster${each.value.cluster_number}-node${each.value.node_number}"
  image_name = "efi-ipxe"
  flavor_name = "m3.small"
  network {
    port = openstack_networking_port_v2.ohpc-btig-port-internal-node["cluster${each.value.cluster_number}-node${each.value.node_number}"].id
  }
}

resource "openstack_networking_port_v2" "ohpc-btig-port-internal-node" {
  for_each = {
    for node in local.compute_nodes : "cluster${node[0]}-node${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  name               = "ohpc-btig-port-internal-cluster${each.value.cluster_number}-node${each.value.node_number}"
  admin_state_up     = "true"
  network_id         = openstack_networking_network_v2.ohpc-btig-internal-network[each.value.cluster_number].id
  # https://access.redhat.com/solutions/2428301
  port_security_enabled = false
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.ohpc-btig-internal-subnet[each.value.cluster_number].id
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-btig-internal-subnet[each.value.cluster_number].cidr, 256 + 1 + each.value.node_number)
  }
}
