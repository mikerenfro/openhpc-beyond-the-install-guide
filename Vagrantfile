# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.
  config.vm.box = "bento/rockylinux-9"
  # config.vm.provider "virtualbox" do |vb|
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  config.vm.provision "shell", inline: <<-SHELL
    /bin/cp /vagrant/repos/opentofu.repo /etc/yum.repos.d/
    yum -y install mtools git gcc tofu python3.12-pip python3.12-devel jq
  SHELL
  config.vm.provision "shell", privileged: false, inline: <<-SHELLUNPRIV    
    ( if [ ! -f /vagrant/openstack-tofu/disk.img ]; then git clone https://github.com/mikerenfro/ohpc-jetstream2.git && cd ohpc-jetstream2 && ./ipxe.sh && cp disk.img /vagrant ; else echo "/vagrant/disk.img already exists"; fi )
    ls -l /vagrant/openstack-tofu/disk.img
    pip3.12 install --user python-openstackclient
    pip3.12 install --user ansible
    pip3.12 install --user xkcdpass
    mkdir -p ~/.bashrc.d/
    cp /vagrant/app-cred-*-openrc.sh ~/.bashrc.d/
    ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
    cat > /vagrant/openstack-tofu/ssh_key.tf <<EOD
variable "ssh_public_key" {
    type = string
    default = "$(cat ~/.ssh/id_ed25519.pub)"
}
EOD
  SHELLUNPRIV
end
