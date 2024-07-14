resource "openstack_networking_network_v2" "intnet" {
  count          = var.n_students+1
  name           = "hpc${count.index}-internal"
  admin_state_up = "true"
}
resource "openstack_networking_subnet_v2" "internal-subnet" {
  count       = var.n_students+1
  network_id  = openstack_networking_network_v2.intnet[count.index].id
  name        = "internal-subnet-${count.index}"
  cidr        = "172.16.0.0/16"
  enable_dhcp = false
}

## https://docs.jetstream-cloud.org/ui/cli/launch/ and
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_v2
resource "openstack_networking_floatingip_v2" "floating-ip-sms" {
  count = var.n_students+1
  pool  = "public"
}
resource "openstack_networking_floatingip_v2" "floating-ip-login" {
  count = var.n_students+1
  pool  = "public"
}
resource "openstack_networking_port_v2" "port-external-sms" {
  count          = var.n_students+1
  name           = "port-external-sms-${count.index}"
  admin_state_up = "true"
  network_id     = openstack_networking_network_v2.extnet.id

  security_group_ids = [openstack_networking_secgroup_v2.ssh-icmp.id]
  fixed_ip {
      subnet_id  = openstack_networking_subnet_v2.external-subnet.id
      ip_address = cidrhost(openstack_networking_subnet_v2.external-subnet.cidr, 256+count.index)
  }
}
resource "openstack_networking_port_v2" "port-external-login" {
  count          = var.n_students+1
  name           = "port-external-login-${count.index}"
  admin_state_up = "true"
  network_id     = openstack_networking_network_v2.extnet.id

  security_group_ids = [openstack_networking_secgroup_v2.ssh-icmp.id]
  fixed_ip {
      subnet_id  = openstack_networking_subnet_v2.external-subnet.id
      ip_address = cidrhost(openstack_networking_subnet_v2.external-subnet.cidr, 384+count.index)
  }
}
resource "openstack_networking_floatingip_associate_v2" "floating-ip-associate-sms" {
  count       = var.n_students+1
  floating_ip = openstack_networking_floatingip_v2.floating-ip-sms[count.index].address
  port_id     = openstack_networking_port_v2.port-external-sms[count.index].id
}
resource "openstack_networking_floatingip_associate_v2" "floating-ip-associate-login" {
  count       = var.n_students+1
  floating_ip = openstack_networking_floatingip_v2.floating-ip-login[count.index].address
  port_id     = openstack_networking_port_v2.port-external-login[count.index].id
}
resource "openstack_networking_port_v2" "port-internal-sms" {
  name           = "port-internal-sms-${count.index}"
  count          = var.n_students+1
  admin_state_up = "true"
  network_id = openstack_networking_network_v2.intnet[count.index].id

  # https://access.redhat.com/solutions/2428301
  port_security_enabled = false
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.internal-subnet[count.index].id
      ip_address = cidrhost(openstack_networking_subnet_v2.internal-subnet[count.index].cidr, 1)
  }
}
resource "openstack_networking_port_v2" "port-internal-login" {
  name           = "port-internal-login-${count.index}"
  count          = var.n_students+1
  admin_state_up = "true"
  network_id = openstack_networking_network_v2.intnet[count.index].id

  # https://access.redhat.com/solutions/2428301
  port_security_enabled = false
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.internal-subnet[count.index].id
      ip_address = cidrhost(openstack_networking_subnet_v2.internal-subnet[count.index].cidr, 2)
  }
}
resource "openstack_compute_instance_v2" "sms" {
  count = var.n_students+1
  name = "hpc${count.index}-sms"
  flavor_name = "m3.small"
  image_name = "Featured-RockyLinux9"
  key_pair = "ohpc-btig-keypair"
  network {
    port = openstack_networking_port_v2.port-external-sms[count.index].id
  }
  network {
    port = openstack_networking_port_v2.port-internal-sms[count.index].id
  }
  user_data = <<-EOF
    #!/bin/bash
    hostnamectl hostname sms
    passwd -d root
    rm -v /root/.ssh/authorized_keys
    yum -q -y update --exclude='kernel*'
    EOF
}

resource "openstack_blockstorage_volume_v3" "opt-ohpc" {
  count = var.n_students+1
  size  = 100
  name  = "hpc${count.index}-opt-ohpc"
}

resource "openstack_compute_volume_attach_v2" "opt-ohpc-attach" {
  count       = var.n_students+1
  instance_id = openstack_compute_instance_v2.sms[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.opt-ohpc[count.index].id
}

resource "openstack_compute_instance_v2" "login" {
  count = var.n_students+1
  name = "hpc${count.index}-login"
  flavor_name = "m3.small"
  image_name = "efi-ipxe"
  # For now, flip the usual order of network connections so that login can provision from eth0
  network {
    port = openstack_networking_port_v2.port-internal-login[count.index].id
  }
  network {
    port = openstack_networking_port_v2.port-external-login[count.index].id
  }
}

locals {
  compute_nodes = setproduct(range(var.n_students+1), range(var.cpu_nodes_per_cluster))
  gpu_nodes = setproduct(range(var.n_students+1), range(var.gpu_nodes_per_cluster))
}

resource "openstack_compute_instance_v2" "node" {
  for_each = {
    for node in local.compute_nodes : "hpc${node[0]}-c${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  name = "hpc${each.value.cluster_number}-c${each.value.node_number+1}"
  image_name = "efi-ipxe"
  flavor_name = "m3.small"
  network {
    port = openstack_networking_port_v2.port-internal-node["hpc${each.value.cluster_number}-c${each.value.node_number}"].id
  }
}

resource "openstack_blockstorage_volume_v3" "vdb-node" {
  for_each = {
    for node in local.compute_nodes : "hpc${node[0]}-c${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  name = "hpc${each.value.cluster_number}-c${each.value.node_number+1}-vdb"
  size  = 10
}

resource "openstack_compute_volume_attach_v2" "vdb-node-attach" {
  for_each = {
    for node in local.compute_nodes : "hpc${node[0]}-c${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  instance_id = openstack_compute_instance_v2.node["hpc${each.value.cluster_number}-c${each.value.node_number}"].id
  volume_id   = openstack_blockstorage_volume_v3.vdb-node["hpc${each.value.cluster_number}-c${each.value.node_number}"].id
}

resource "openstack_networking_port_v2" "port-internal-node" {
  for_each = {
    for node in local.compute_nodes : "hpc${node[0]}-c${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  name               = "port-internal-hpc${each.value.cluster_number}-c${each.value.node_number}"
  admin_state_up     = "true"
  network_id         = openstack_networking_network_v2.intnet[each.value.cluster_number].id
  # https://access.redhat.com/solutions/2428301
  port_security_enabled = false
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.internal-subnet[each.value.cluster_number].id
      ip_address = cidrhost(openstack_networking_subnet_v2.internal-subnet[each.value.cluster_number].cidr, 256 + 1 + each.value.node_number)
  }
}

resource "openstack_compute_instance_v2" "gpunode" {
  for_each = {
    for node in local.gpu_nodes : "hpc${node[0]}-g${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  name = "hpc${each.value.cluster_number}-g${each.value.node_number+1}"
  image_name = "efi-ipxe"
  flavor_name = "g3.small"
  network {
    port = openstack_networking_port_v2.port-internal-gpunode["hpc${each.value.cluster_number}-g${each.value.node_number}"].id
  }
}

resource "openstack_blockstorage_volume_v3" "vdb-gpunode" {
  for_each = {
    for node in local.compute_nodes : "hpc${node[0]}-g${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  name = "hpc${each.value.cluster_number}-g${each.value.node_number+1}-vdb"
  size  = 20
}

resource "openstack_compute_volume_attach_v2" "vdb-gpunode-attach" {
  for_each = {
    for node in local.compute_nodes : "hpc${node[0]}-g${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  instance_id = openstack_compute_instance_v2.gpunode["hpc${each.value.cluster_number}-g${each.value.node_number}"].id
  volume_id   = openstack_blockstorage_volume_v3.vdb-gpunode["hpc${each.value.cluster_number}-g${each.value.node_number}"].id
}

resource "openstack_networking_port_v2" "port-internal-gpunode" {
  for_each = {
    for node in local.gpu_nodes : "hpc${node[0]}-g${node[1]}" => {
      cluster_number = node[0]
      node_number = node[1]
    }
  }
  name               = "port-internal-hpc${each.value.cluster_number}-g${each.value.node_number}"
  admin_state_up     = "true"
  network_id         = openstack_networking_network_v2.intnet[each.value.cluster_number].id
  # https://access.redhat.com/solutions/2428301
  port_security_enabled = false
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.internal-subnet[each.value.cluster_number].id
      ip_address = cidrhost(openstack_networking_subnet_v2.internal-subnet[each.value.cluster_number].cidr, 512 + 1 + each.value.node_number)
  }
}
