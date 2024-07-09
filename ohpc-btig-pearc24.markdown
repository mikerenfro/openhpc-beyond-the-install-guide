---
author:
- Sharon Colson
- Jim Moroney
- Mike Renfro
institute:
- Tennessee Tech University
title: "OpenHPC: Beyond the Install Guide"
subtitle: for PEARC24
date: 2024-07-22
aspectratio: 169
theme: Cookeville
section-titles: false
toc: false
---

# Introduction

## Acknowledgments and shameless plugs

### Acknowledgments and shameless plugs

OpenHPC

: especially Tim Middelkoop (Internet2) and Chris Simmons (Massachusetts Green High Performance Computing Center ). They have a BOF at 1:30 Wednesday. You should go to it.

Jetstream2

: especially Jeremy Fischer, Mike Lowe, and Julian Pistorius. Jetstream2 has a tutorial at the same time as this one. Please stay here.

NSF CC*

: for the equipment that led to some of the lessons we're sharing today (award #2127188).

ACCESS

: current maintainers of the project formerly known as the XSEDE Compatible Basic Cluster.

::: notes
x
:::

## Where we're starting from

### Where we're starting from
::: {.columns align=center}

::: {.column width=50%}
![Two example HPC networks]

[Two example HPC networks]: figures/two-networks.png { width=100% }
:::

::: {.column width=50%}
31 HPC clusters (2 shown) with:

1. Rocky Linux 9
2. OpenHPC 3
3. Warewulf 3
4. Slurm
5. 2 non-GPU nodes
6. 2 GPU nodes (currently without GPU drivers, so: expensive non-GPU nodes)
7. 1 management node (SMS)
8. 1 unprovisioned login node
:::

:::

::: notes
x
:::

### Where we're starting from

We used the OpenHPC automatic installation script from Appendix A with a few variations:

1. Installed `s-nail` to have a valid `MailProg` for `slurm.conf`.
2. Created `user1` and `user2` accounts with password-less `sudo` privileges.
3. Changed `CHROOT` from `/opt/ohpc/admin/images/rocky9.3` to `/opt/ohpc/admin/images/rocky9.4`.
4. Enabled `slurmd` and `munge` in `CHROOT`.
5. Added `nano` and `yum` to `CHROOT`.
6. Removed a redundant `ReturnToService` line from `/etc/slurm/slurm.conf`.
7. Stored all nodes' SSH host keys in `/etc/ssh/ssh_known_hosts`.

::: notes
x
:::

## Where we're going

### Where we're going

1. A slightly more secured SMS
2. A login node that's practically identical to a compute node (except for where it needs to be different)
3. GPU drivers on the GPU nodes
4. Using node-local storage for the OS and/or scratch
5. De-coupling the SMS and the compute nodes (e.g., independent kernel versions)
6. Easier management of node differences (GPU or not, diskless/single-disk/multi-disk, Infiniband or not, etc.)
7. Slurm configuration to match some common policy goals (fair share, resource limits, etc.)

::: notes
x
:::

# Making better nodes

## A bit more security for the SMS

## A dedicated login node

### Assumptions

1. We have a VM named `login`, with no operating system installed.
2. The `eth0` network interface for `login` is attached to the internal network, and `eth1` is attached to the external network.
3. The `eth0` MAC address for `login` is known---check the **Login server** section of your handout for that. It's of the format `aa:bb:cc:dd:ee:ff`.
4. We're logged into the SMS as `user1` or `user2` that has `sudo` privileges.

### Creating a new login node

Working from section 3.9.3 of the install guide:
```
[user1@sms-0 ~]$ sudo wwsh -y node new login --ipaddr=172.16.0.2 \
    --hwaddr=__:__:__:__:__:__ -D eth0
[user1@sms-0 ~]$ sudo wwsh -y provision set login --vnfs=rocky9.4 \
    --bootstrap=`uname -r` \
    --files=dynamic_hosts,passwd,group,shadow,munge.key,network
```

**Make sure to replace the `__` with the characters from your login node's MAC address!**

## Semi-stateful node provisioning

## Management of GPU drivers

# Managing system complexity

## Configuration settings for different node types

## Automation for Warewulf3 provisioning

# Configuring Slurm policies

### Sample slide

::: {.columns align=center}

::: {.column width=65%}
#### Left column

This slide has two columns. They don't always have to have columns. It also has a titled block of content in the left column. Make sure you've always got a `::: notes` block after the slide content, even if it has no content.
:::

::: {.column width=35%}
Use `#` and `##` headers in the Markdown file to make level-1 and level-2 headings, `###` headers to make slide titles, and `####` to make block titles.
:::

:::

::: notes

This is my note.

- It can contain Markdown
- like this list

:::
