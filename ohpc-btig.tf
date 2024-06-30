# Following along with https://docs.jetstream-cloud.org/ui/cli/overview/

## https://docs.jetstream-cloud.org/ui/cli/managing-ssh-keys/ and
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/compute_keypair_v2
## Define an SSH public key that will be added to the OpenHPC management node's user's authorized_keys file
resource "openstack_compute_keypair_v2" "ohpc-btig-keypair" {
  name       = "ohpc-btig-keypair"
  public_key = var.ssh_public_key
}

## https://docs.jetstream-cloud.org/ui/cli/security_group/ and
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_v2
## Define a security group to allow inbound ping and SSH
resource "openstack_networking_secgroup_v2" "ohpc-btig-ssh-icmp" {
  name        = "ohpc-btig-ssh-icmp"
  description = "ssh and icmp enabled"
}
## Create SSH access rules from home and from work
resource "openstack_networking_secgroup_rule_v2" "ohpc-btig-ssh-home" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.home_ip_range
  security_group_id = openstack_networking_secgroup_v2.ohpc-btig-ssh-icmp.id
}
resource "openstack_networking_secgroup_rule_v2" "ohpc-btig-ssh-work" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.work_ip_range
  security_group_id = openstack_networking_secgroup_v2.ohpc-btig-ssh-icmp.id
}
## Create ICMP access rules from home and from work
resource "openstack_networking_secgroup_rule_v2" "ohpc-btig-icmp-home" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.home_ip_range
  security_group_id = openstack_networking_secgroup_v2.ohpc-btig-ssh-icmp.id
}
resource "openstack_networking_secgroup_rule_v2" "ohpc-btig-icmp-work" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.work_ip_range
  security_group_id = openstack_networking_secgroup_v2.ohpc-btig-ssh-icmp.id
}
## Define a security group to allow all traffic on internal network segment
resource "openstack_networking_secgroup_v2" "ohpc-btig-allow-all" {
  name        = "ohpc-btig-allow-all"
  description = "all traffic enabled"
}
## Create all-traffic access rules for internal network segment
resource "openstack_networking_secgroup_rule_v2" "ohpc-btig-allow-all-internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "172.16.0.0/16"
  security_group_id = openstack_networking_secgroup_v2.ohpc-btig-allow-all.id
}


## https://docs.jetstream-cloud.org/ui/cli/network/ and
## https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_network_v2
resource "openstack_networking_network_v2" "ohpc-btig-external-network" {
  name           = "ohpc-btig-external-network"
  admin_state_up = "true"
}
resource "openstack_networking_network_v2" "ohpc-btig-internal-network" {
  name           = "ohpc-btig-internal-network"
  admin_state_up = "true"
}
resource "openstack_networking_subnet_v2" "ohpc-btig-external-subnet" {
  network_id = openstack_networking_network_v2.ohpc-btig-external-network.id
  name       = "ohpc-btig-external-subnet"
  cidr       = "10.38.50.0/24"
}
resource "openstack_networking_subnet_v2" "ohpc-btig-internal-subnet" {
  network_id = openstack_networking_network_v2.ohpc-btig-internal-network.id
  name       = "ohpc-btig-internal-subnet"
  cidr       = "172.16.0.0/16"
}
resource "openstack_networking_router_v2" "ohpc-btig-router" {
  name                = "ohpc-btig-router"
  admin_state_up      = true
  external_network_id = var.openstack_public_router_id
}
resource "openstack_networking_router_interface_v2" "ohpc-btig-router-interface-external-subnet" {
  router_id = openstack_networking_router_v2.ohpc-btig-router.id
  subnet_id = openstack_networking_subnet_v2.ohpc-btig-external-subnet.id
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
      ip_address = cidrhost(openstack_networking_subnet_v2.ohpc-btig-external-subnet.cidr, 8)
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

## Output

### Create an Ansible inventory on the local system, including the OpenHPC managment node's external IP
resource "local_file" "ansible" {
  filename = "ansible/local.ini"
  content = <<-EOF
    ## auto-generated
    [ohpc]
    head ansible_host=${openstack_networking_floatingip_v2.ohpc-btig-floating-ip-sms.address} ansible_user=rocky arch=x86_64

    [ohpc:vars]
    # sshkey=${var.ssh_public_key}
    EOF
}

### Show the OpenHPC management node's external IPv4 address, so that it can be accessed with "ssh rocky@OHPC_IP"
output "ohpc-btig-sms-ipv4" {
  value = openstack_networking_floatingip_v2.ohpc-btig-floating-ip-sms.address
}
