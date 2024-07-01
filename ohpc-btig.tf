resource "openstack_networking_network_v2" "ohpc-btig-internal-network" {
  name           = "ohpc-btig-internal-network"
  admin_state_up = "true"
}
resource "openstack_networking_subnet_v2" "ohpc-btig-internal-subnet" {
  network_id = openstack_networking_network_v2.ohpc-btig-internal-network.id
  name       = "ohpc-btig-internal-subnet"
  cidr       = "172.16.0.0/16"
}

## https://docs.jetstream-cloud.org/ui/cli/launch/ and
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_instance_v2
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_floatingip_v2
resource "openstack_networking_floatingip_v2" "ohpc-btig-floating-ip-sms" {
  pool = "public"
}
resource "openstack_networking_port_v2" "ohpc-btig-port-external-sms" {
  name           = "ohpc-btig-port-external-sms"
  admin_state_up = "true"
  network_id = openstack_networking_network_v2.ohpc-btig-external-network.id

  security_group_ids = [openstack_networking_secgroup_v2.ohpc-btig-ssh-icmp.id]
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.ohpc-btig-external-subnet.id
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-btig-external-subnet.cidr, 3)
  }
}
resource "openstack_networking_floatingip_associate_v2" "ohpc-btig-floating-ip-associate-sms" {
  floating_ip = openstack_networking_floatingip_v2.ohpc-btig-floating-ip-sms.address
  port_id = openstack_networking_port_v2.ohpc-btig-port-external-sms.id
}
resource "openstack_networking_port_v2" "ohpc-btig-port-internal-sms" {
  name           = "ohpc-btig-port-internal-sms"
  admin_state_up = "true"
  network_id = openstack_networking_network_v2.ohpc-btig-internal-network.id

  security_group_ids = [openstack_networking_secgroup_v2.ohpc-btig-allow-all.id]
  fixed_ip {
      subnet_id = openstack_networking_subnet_v2.ohpc-btig-internal-subnet.id
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-btig-internal-subnet.cidr, 1)
  }
}
resource "openstack_compute_instance_v2" "ohpc-btig-sms" {
  name = "sms"
  flavor_name = "m3.small"
  image_name = "Featured-RockyLinux9"
  key_pair = "ohpc-btig-keypair"
  network {
    port = openstack_networking_port_v2.ohpc-btig-port-external-sms.id
  }
  network {
    port = openstack_networking_port_v2.ohpc-btig-port-internal-sms.id
  }
  user_data = <<-EOF
    #!/bin/bash
    passwd -d root
    rm -v /root/.ssh/authorized_keys
    EOF
}

resource "openstack_compute_instance_v2" "node" {
  count = 2
  name = "c${count.index}"
  image_name = "efi-ipxe"
  flavor_name = "m3.small"
  network {
    uuid = openstack_networking_network_v2.ohpc-btig-internal-network.id
    fixed_ip_v4 = cidrhost(openstack_networking_subnet_v2.ohpc-btig-internal-subnet.cidr, 256 + count.index)
  }
  security_groups = [openstack_networking_secgroup_v2.ohpc-btig-allow-all.name]
}
