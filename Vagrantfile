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
    yum -y install mtools git gcc
  SHELL
  config.vm.provision "shell", privileged: false, inline: <<-SHELLUNPRIV
    git clone https://github.com/mikerenfro/ohpc-jetstream2.git
    ( cd ohpc-jetstream2 && ./ipxe.sh && cp disk.img /vagrant )
    ls -l /vagrant/disk.img
  SHELLUNPRIV
end
