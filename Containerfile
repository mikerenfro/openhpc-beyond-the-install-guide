FROM registry.docker.com/library/rockylinux:9

## Setup OS
RUN dnf update -y && \
    dnf install -y dnf-plugins-core && \
    dnf config-manager --set-enabled crb && \
    dnf install -y git python3 ca-certificates procps-ng wget unzip jq && \
    dnf install -y iproute bind-utils findutils && \
    dnf clean packages

## Setup environment
COPY repos/opentofu.repo /etc/yum.repos.d/
RUN yum -y install mtools git gcc tofu python3.12-pip python3.12-devel jq

## Tools
RUN pip3.12 install --user python-openstackclient && \
    pip3.12 install --user ansible && \
    pip3.12 install --user xkcdpass

## Cross compiler for arm machines
RUN dnf install -y epel-release && \
    dnf install -y gcc-x86_64-linux-gnu

## Setup
WORKDIR /vagrant

## iPXE (build if needed)
COPY ipxe/ /vagrant/ipxe/
RUN if [ ! -f /vagrant/ipxe/disk.img ]; then cd /vagrant/ipxe ; bash ./ipxe.sh ; fi

## Openstack
COPY openstack-tofu/ /vagrant/openstack-tofu/
RUN cp /vagrant/ipxe/disk.img /vagrant/openstack-tofu/ && \
    ls -l /vagrant/openstack-tofu/disk.img

## Ansible
COPY ansible/ /vagrant/ansible/

## Setup profile
RUN cp /etc/skel/.bashrc ~/ && \
    mkdir -p ~/.bashrc.d/ && \
    cp /vagrant/openstack-tofu/app-cred-*-openrc.sh ~/.bashrc.d/ && \
    echo "unset SSH_AUTH_SOCK" > ~/.bashrc.d/unset_ssh_auth_sock.sh && \
    ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 && \
    echo -e "variable \"ssh_public_key\" {\n type = string\n default = \"$(cat ~/.ssh/id_ed25519.pub)\"\n}" > /vagrant/openstack-tofu/ssh_key.tf
