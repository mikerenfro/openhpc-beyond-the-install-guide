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
    /bin/cp /vagrant/opentofu.repo /etc/yum.repos.d/
    yum -y install mtools git gcc tofu python3-pip
  SHELL
  config.vm.provision "shell", privileged: false, inline: <<-SHELLUNPRIV
    git clone https://github.com/mikerenfro/ohpc-jetstream2.git
    ( if [ ! -f /vagrant/disk.img ]; then cd ohpc-jetstream2 && ./ipxe.sh && cp disk.img /vagrant ; else echo "/vagrant/disk.img already exists"; fi )
    ls -l /vagrant/disk.img
    pip install --user python-openstackclient
    pip install --user ansible
  SHELLUNPRIV
end
