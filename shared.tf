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
resource "openstack_networking_subnet_v2" "ohpc-btig-external-subnet" {
  network_id = openstack_networking_network_v2.ohpc-btig-external-network.id
  name       = "ohpc-btig-external-subnet"
  cidr       = "10.38.50.0/24"
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

## Output

### Create an Ansible inventory on the local system, including the OpenHPC managment node's external IP
resource "local_file" "ansible" {
  filename = "ansible/local.ini"
  content = <<-EOF
    ## auto-generated
    [ohpc]
    sms ansible_host=${openstack_networking_floatingip_v2.ohpc-btig-floating-ip-sms.address} ansible_user=rocky arch=x86_64 ansible_python_interpreter=/usr/bin/python3.9

    [ohpc:vars]
    # sshkey=${var.ssh_public_key}
    EOF
}

### Show the OpenHPC management node's external IPv4 address, so that it can be accessed with "ssh rocky@OHPC_IP"
output "ohpc-btig-sms-ipv4" {
  value = openstack_networking_floatingip_v2.ohpc-btig-floating-ip-sms.address
}
