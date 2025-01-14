# (Mostly) Making a login node

Assumptions:
1. the instance is already connected to the internal network on eth0 and to the external network on eth1.
2. the instance internal MAC address is known

## wwsh changes

```
[user1@sms-0 ~]$ sudo wwsh -y node new login --ipaddr=172.16.0.2 --hwaddr=fa:16:3e:4c:8a:97 -D eth0
[user1@sms-0 ~]$ sudo wwsh -y provision set login --vnfs=rocky9.4 --bootstrap=`uname -r` --files=dynamic_hosts,passwd,group,shadow,munge.key,network
```

Node will boot now, and it looks like everything's good. Can ssh to it as root, NFS filesystems all mounted, too.

## Slurm changes

Bad news, though, running `sinfo` on the login node fails with the not too helpful error messages of

```
sinfo: error: resolve_ctls_from_dns_srv: res_nsearch error: Unknown host
sinfo: error: fetch_config: DNS SRV lookup failed
sinfo: error: _establish_config_source: failed to fetch config
sinfo: fatal: Could not establish a configuration source
```

### Option 1: take the error message literally

`systemctl status slurmd` is more helpful, with `fatal: Unable to determine this slurmd's NodeName`.

So there's no entry for login in the SMS `slurm.conf`. To fix that:

1. Run `slurmd -C` on the login node to capture its correct CPU specifications. Copy that line to your laptop's clipboard.
2. On the SMS, run `nano /etc/slurm/slurm/slurm.conf` and make a new line of all the `slurmd -C` output from the previous step (pasted from your laptop clipboard).
3. Save and exit `nano` by pressing `Ctrl-X` and then Enter.
4. Reload the new Slurm configuration everywhere (well, everywhere functional) with `sudo scontrol reconfigure` on the SMS.
5. ssh back to the login node and restart slurmd, since it wasn't able to respond to the `scontrol reconfigure` from the previous step (`sudo ssh login systemctl restart slurmd` on the SMS).

Now an `sinfo` should work on the login node:

```
[root@login ~]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 1-00:00:00      1   idle c1
```

### Option 2: why are we running `slurmd` anyway?

The `slurmd` service is really only needed on systems that will be running computational jobs, and the login node is not in that category.

Running `slurmd` like the other nodes means the login node can get all its information from the SMS, but we can do the same thing with a very short customized `slurm.conf` with two lines from the SMS' `slurm.conf`:

```
ClusterName=cluster
SlurmctldHost=sms-0
```

(where `sms-0` should be **your** SMS hostname from your handout) and stopping/disabling the `slurmd` service.

#### Interactive testing

1. On the login node as `root`, temporarily stop the `slurmd` service with `systemctl stop slurmd`.
2. On the login node as `root`, edit `/etc/slurm/slurm.conf` with `nano /etc/slurm/slurm.conf`
3. Add the two lines above.
4. Save and exit `nano` by pressing `Ctrl-X` and then Enter.

Verify that `sinfo` still works without `slurmd` and with the custom `/etc/slurm/slurm.conf`.

```
[root@login ~]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 1-00:00:00      1   idle c1
```

#### Making permanent changes from the SMS

Let's reproduce the changes we made interactively on the login node in the Warewulf settings on the SMS.

For the customized `slurm.conf` file, we can keep a copy of it on the SMS and add it to the Warewulf file store.
We've done that previously for files like the shared `munge.key` for all cluster nodes (see section 3.8.5 of the OpenHPC install guide).
We also need to make sure that file is part of the login node's provisioning settings.

On the SMS:
```
[user1@sms-0 ~]$ sudo scp login:/etc/slurm/slurm.conf /etc/slurm/slurm.conf.login
slurm.conf                                    100%   40    57.7KB/s   00:00
[user1@sms-0 ~]$ sudo wwsh -y file import /etc/slurm/slurm.conf.login --name=slurm.conf.login --path=/etc/slurm/slurm.conf
```

Now the file is available, but we need to ensure the login node gets it. That's handled with `wwsh provision`.

```
[user1@sms-0 ~]$ wwsh provision print c1
#### c1 #######################################################################
             c1: MASTER           = UNDEF
             c1: BOOTSTRAP        = 6.1.96-1.el9.elrepo.x86_64
             c1: VNFS             = rocky9.4
             c1: VALIDATE         = FALSE
             c1: FILES            = dynamic_hosts,group,munge.key,network,passwd,shadow
             c1: PRESHELL         = FALSE
             c1: POSTSHELL        = FALSE
             c1: POSTNETDOWN      = FALSE
             c1: POSTREBOOT       = FALSE
             c1: CONSOLE          = UNDEF
             c1: TRANSPORT        = UNDEF
             c1: PXELOADER        = UNDEF
             c1: IPXEURL          = UNDEF
             c1: SELINUX          = DISABLED
             c1: UCODE            = UNDEF
             c1: KARGS            = "net.ifnames=0 biosdevname=0 quiet"
             c1: BOOTLOCAL        = FALSE
[user1@sms-0 ~]$ wwsh provision print login
#### login ####################################################################
          login: MASTER           = UNDEF
          login: BOOTSTRAP        = 6.1.96-1.el9.elrepo.x86_64
          login: VNFS             = rocky9.4
          login: VALIDATE         = FALSE
          login: FILES            = dynamic_hosts,group,munge.key,network,passwd,shadow
          login: PRESHELL         = FALSE
          login: POSTSHELL        = FALSE
          login: POSTNETDOWN      = FALSE
          login: POSTREBOOT       = FALSE
          login: CONSOLE          = UNDEF
          login: TRANSPORT        = UNDEF
          login: PXELOADER        = UNDEF
          login: IPXEURL          = UNDEF
          login: SELINUX          = DISABLED
          login: UCODE            = UNDEF
          login: KARGS            = "net.ifnames=0 biosdevname=0 quiet"
          login: BOOTLOCAL        = FALSE
```

These are actually identical for now, but eyeballing it is difficult. I could diff the outputs, but every line has a nodename, rendering the diffs mostly useless. So let's filter the outputs before diffing them.

I only care about the lines with `=` signs on them, so `wwsh provision print c1 | grep =` is a start.
Now all the lines are prefixed with `c1:`, and I want to keep everything after that, so `wwsh provision print c1 | grep = | cut -d: -f2-` should take care of that:

```
[user1@sms-0 ~]$ wwsh provision print c1 | grep = | cut -d: -f2-
 MASTER           = UNDEF
 BOOTSTRAP        = 6.1.96-1.el9.elrepo.x86_64
 VNFS             = rocky9.4
 VALIDATE         = FALSE
 FILES            = dynamic_hosts,group,munge.key,network,passwd,shadow
 PRESHELL         = FALSE
 POSTSHELL        = FALSE
 POSTNETDOWN      = FALSE
 POSTREBOOT       = FALSE
 CONSOLE          = UNDEF
 TRANSPORT        = UNDEF
 PXELOADER        = UNDEF
 IPXEURL          = UNDEF
 SELINUX          = DISABLED
 UCODE            = UNDEF
 KARGS            = "net.ifnames=0 biosdevname=0 quiet"
 BOOTLOCAL        = FALSE
```

We may be typing that command pipeline a lot, so let's make a shell function to cut down on typing:
```
[user1@sms-0 ~]$ function proprint() { wwsh provision print $@ | grep = | cut -d: -f2- ; }
[user1@sms-0 ~]$ proprint c1
...
```


We could redirect a `proprint c1` and a `proprint login` to files and diff the files, or we can use the shell's `<()` operator to treat command output as a file:

```
[user1@sms-0 ~]$ diff -u <(proprint c1) <(proprint login)
[user1@sms-0 ~]$
```

Either of those shows there are zero provisioning differences between a compute node and the login node.

Add a file to login's `FILES` property with `sudo wwsh -y provision set login --fileadd=slurm.conf.login` (refer to section 3.9.3 of the install guide for previous examples of `--fileadd`).

Rerun the previous diff command to see what's changed:

```
[user1@sms-0 ~]$ diff -u <(proprint c1) <(proprint login)
--- /dev/fd/63  2024-07-06 11:11:07.682959677 -0400
+++ /dev/fd/62  2024-07-06 11:11:07.683959681 -0400
@@ -2,7 +2,7 @@
  BOOTSTRAP        = 6.1.96-1.el9.elrepo.x86_64
  VNFS             = rocky9.4
  VALIDATE         = FALSE
- FILES            = dynamic_hosts,group,munge.key,network,passwd,shadow
+ FILES            = dynamic_hosts,group,munge.key,network,passwd,shadow,slurm.conf.login
  PRESHELL         = FALSE
  POSTSHELL        = FALSE
  POSTNETDOWN      = FALSE
```

For disabling the `slurmd` service on just the login node, we can take advantage of conditions in the `systemd` service file.
Back on the login node as `root`, `systemctl edit slurmd`.
Insert three lines between the lines of `### Anything between here...` and `### Lines below this comment...`:

```
[Unit]
ConditionHost=|c*
ConditionHost=|g*
```

Once that file is saved, try to start the `slurmd` service with `systemctl start slurmd` and check its status with `systemctl status slurmd`:

```
○ slurmd.service - Slurm node daemon
     Loaded: loaded (/usr/lib/systemd/system/slurmd.service; enabled; preset: d>
    Drop-In: /etc/systemd/system/slurmd.service.d
             └─override.conf
     Active: inactive (dead) since Sat 2024-07-06 17:14:16 EDT; 1h 2min ago
   Duration: 6min 17.247s
  Condition: start condition failed at Sat 2024-07-06 18:12:17 EDT; 4min 22s ago
   Main PID: 1132 (code=exited, status=0/SUCCESS)
        CPU: 159ms
...
Jul 06 17:14:16 login systemd[1]: Stopped Slurm node daemon.
Jul 06 18:12:17 login systemd[1]: Slurm node daemon was skipped because of an unmet condition check (ConditionHost=c*).
```

The `systemctl edit` command resulted in a file `/etc/systemd/system/slurmd.service.d/override.conf`.
Let's make a place for it in the chroot on the SMS, copy the file over from the login node, and rebuild the VNFS.
Finally, we'll reboot both the login node and a compute node to test the changes.
```
[user1@sms-0 ~]$ sudo mkdir -p /opt/ohpc/admin/images/rocky9.4/etc/systemd/system/slurmd.service.d/
[user1@sms-0 ~]$ sudo scp login:/etc/systemd/system/slurmd.service.d/override.conf /opt/ohpc/admin/images/rocky9.4/etc/systemd/system/slurmd.service.d/
override.conf                                 100%   23    36.7KB/s   00:00
[user1@sms-0 ~]$ sudo wwvnfs --chroot=/opt/ohpc/admin/images/rocky9.4
Using 'rocky9.4' as the VNFS name
...
Total elapsed time                                          : 84.45 s
[user1@sms-0 ~]$ sudo ssh login reboot
[user1@sms-0 ~]$ sudo ssh c1 reboot
```

Verify that the login node doesn't start `slurmd`, but can still run `sinfo` without any error messages.
```
[user1@sms-0 ~]$ sudo ssh login systemctl status slurmd
○ slurmd.service - Slurm node daemon
...
Jul 06 18:26:23 login systemd[1]: Slurm node daemon was skipped because of an unmet condition check (ConditionHost=c*).
[user1@sms-0 ~]$ sudo ssh login sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 1-00:00:00      1   idle c1
```

Verify that the compute node still starts `slurmd` (it can also run `sinfo`).
```
[user1@sms-0 ~]$ sudo ssh c1 systemctl status slurmd
● slurmd.service - Slurm node daemon
...
Jul 06 19:03:22 c1 systemd[1]: Started Slurm node daemon.
Jul 06 19:03:22 c1 slurmd[1082]: slurmd: CPUs=2 Boards=1 Sockets=2 Cores=1 Threads=1 Memory=5912 TmpDisk=2956 Uptime=28 CPUSpecList=(null) FeaturesAvail=(null) FeaturesActive=(null)
[user1@sms-0 ~]$ sudo ssh c1 sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 1-00:00:00      1   down c1
```

You can return `c1` to an idle state by running `sudo scontrol update node=c1 state=resume` on the SMS:
```
[user1@sms-0 ~]$ sudo scontrol update node=c1 state=resume
[user1@sms-0 ~]$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 1-00:00:00      1   idle c1
```

We should configure things so that we don't have to resume nodes every time we reboot them.

## More seamless reboots of compute nodes

Slurm doesn't like it when a node gets rebooted without its knowledge.
There's an `scontrol reboot` option that's handy to have nodes reboot when system updates occur, but it requires a valid setting for `RebootProgram` in `/etc/slurm/slurm.conf`.

By default, Slurm and OpenHPC don't ship with a default `RebootProgram`, so let's make one.

```
[user1@sms-0 ~]$ grep -i reboot /etc/slurm/slurm.conf
#RebootProgram=
[user1@sms-0 ~]$ echo 'RebootProgram="/usr/sbin/shutdown -r now"' | sudo tee -a /etc/slurm/slurm.conf
[user1@sms-0 ~]$ grep -i reboot /etc/slurm/slurm.conf
#RebootProgram=
RebootProgram="/usr/sbin/shutdown -r now"
[user1@sms-0 ~]$ sudo scontrol reconfigure
[user1@sms-0 ~]$ sudo scontrol reboot ASAP nextstate=RESUME c1
```

- `scontrol reboot` will wait for all jobs on a group of nodes to finish before rebooting the nodes.
- `scontrol reboot ASAP` will immediately put the nodes in a `DRAIN` state, routing all pending jobs to other nodes until the rebooted nodes are returned to service.
- `scontrol reboot ASAP nextstate=RESUME` will set the nodes to accept jobs after the reboot. `nextstate=DOWN` will lave the nodes in a `DOWN` state if you need to do more work on them before returning them to service.

## `ssh` changes

What if we ssh to the login node as someone other than root?

```
[user1@sms-0 ~]$ ssh login
Access denied: user user1 (uid=1001) has no active jobs on this node.
Connection closed by 172.16.0.2 port 22
```

which makes this currently the opposite of a login node for normal users.
This is caused by the `pam_slurm.so` entry at the end of `/etc/pam.d/sshd`, which is invaluable on a normal compute node, but not on a login node.
On the SMS, you can also do a `diff -u /etc/pam.d/sshd /opt/ohpc/admin/images/rocky9.4/etc/pam.d/sshd` to see that the `pam_slurm.so` is the only difference between the two files.

Temporarily comment out the last line of the login node's `/etc/pam.d/ssh` and see if you can ssh into the login node. You should be able to, but in case you totally screw up the PAM configuration to where not even root can log in, we can just reboot the login node from its console to put it back to the defaults.

So we want to ensure that the login node gets a more typical `/etc/pam.d/sshd`.
We'll follow the same method we used to give the login node a custom `slurm.conf`:
```
[user1@sms-0 ~]$ sudo wwsh -y file import /etc/pam.d/sshd --name=sshd.login
[user1@sms-0 ~]$ wwsh file list
dynamic_hosts           :  rw-r--r-- 0   root root              835 /etc/hosts
group                   :  rw-r--r-- 1   root root             1104 /etc/group
munge.key               :  r-------- 1   munge munge           1024 /etc/munge/munge.key
network                 :  rw-r--r-- 1   root root               16 /etc/sysconfig/network
passwd                  :  rw-r--r-- 1   root root             2766 /etc/passwd
shadow                  :  rw-r----- 1   root root             1424 /etc/shadow
slurm.conf.login        :  rw-r--r-- 1   root root               40 /etc/slurm/slurm.conf
sshd.login              :  rw-r--r-- 1   root root              727 /etc/pam.d/sshd
[user1@sms-0 ~]$ sudo wwsh -y provision set login --fileadd=sshd.login
[user1@sms-0 ~]$ diff -u <(proprint c1) <(proprint login)
--- /dev/fd/63	2024-07-06 19:25:21.725067514 -0400
+++ /dev/fd/62	2024-07-06 19:25:21.726067524 -0400
@@ -2,7 +2,7 @@
  BOOTSTRAP        = 6.1.96-1.el9.elrepo.x86_64
  VNFS             = rocky9.4
  VALIDATE         = FALSE
- FILES            = dynamic_hosts,group,munge.key,network,passwd,shadow
+ FILES            = dynamic_hosts,group,munge.key,network,passwd,shadow,slurm.conf.login,sshd.login
  PRESHELL         = FALSE
  POSTSHELL        = FALSE
  POSTNETDOWN      = FALSE
```

Reboot the login node and let's see if we can log in as a regular user.

```
[user1@sms-0 ~]$ sudo ssh login reboot
[user1@sms-0 ~]$ ssh login
[user1@login ~]$
```

## Brute-force ssh protection

**Verify if this will work on the SMS with a simple `sudo yum install fail2ban ; sudo systemctl enable fail2ban firewalld`**

`firewalld` on the SMS will be mildly complicated for this time constraint. `eth0` and `eth1` are in the default public zone, so we'd have to:

- put them in separate zones
- add rules/policy to the external zone
- not break things

May be simpler to say that in production, the external HPC interfaces should be in a protected VLAN, the SMS might only take key-based logins, and continue on with the login node since that may be more exposed to users and pretty much has to allow password-based logins.

**Also work in notes on running both fail2ban and firewalld on the login node**

Look what will show up in the SMS `/var/log/secure` within just a few minutes of having `ssh` enabled on the login node:

```
Jul  6 11:13:55 login sshd[1190]: Invalid user ubuntu from 103.177.95.251 port 56186
Jul  6 11:13:55 login sshd[1190]: pam_unix(sshd:auth): check pass; user unknown
Jul  6 11:13:55 login sshd[1190]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=103.177.95.251
Jul  6 11:13:57 login sshd[1190]: Failed password for invalid user ubuntu from 103.177.95.251 port 56186 ssh2
Jul  6 11:13:59 login sshd[1190]: Received disconnect from 103.177.95.251 port 56186:11: Bye Bye [preauth]
Jul  6 11:13:59 login sshd[1190]: Disconnected from invalid user ubuntu 103.177.95.251 port 56186 [preauth]
```

Let's stop that by configuring `fail2ban` on the login node.

Install the fail2ban packages on the login node with `sudo ssh login yum -y install fail2ban` and `sudo ssh login systemctl start fail2ban` (this will also install `firewalld`).

Install the fail2ban package in the chroot with: `sudo yum install --installroot=/opt/ohpc/admin/images/rocky9.4 fail2ban` and `sudo chroot /opt/ohpc/admin/images/rocky9.4 systemctl enable fail2ban firewalld`

Add the following to the chroot's jail.local file with `sudo nano /opt/ohpc/admin/images/rocky9.4/etc/fail2ban/jail.d/sshd.local`:

```
[sshd]
enabled = true
```

Just out of curiosity, does the login node have anything in its `/var/log/secure` that `fail2ban` can react to?

```
[rocky@sms-0 ~]$ ssh login ls -l /var/log/secure
-rw------- 1 root root 0 Jul  6 09:58 /var/log/secure
```

Nope.
We need to ensure things get logged to `/var/log/secure`.
Looking in `/etc/rsyslog.conf`, we see a bunch of things commented out, including the line `#authpriv.* /var/log/secure`.
Rather than drop in an entirely new rsyslog.conf file that we'd have to maintain, rsyslog will automatically include any `*.conf` files in `/etc/rsyslog.d`.
Let's make one of those for the chroot.

```
[user1@sms-0 ~]$ echo "authpriv.* /var/log/secure" | sudo tee /opt/ohpc/admin/images/rocky9.4/etc/rsyslog.d/authpriv-local.conf
authpriv.* /var/log/secure
[user1@sms-0 ~]$ cat /opt/ohpc/admin/images/rocky9.4/etc/rsyslog.d/authpriv-local.conf
authpriv.* /var/log/secure
```

Rebuild the chroot with `sudo wwvnfs --chroot=/opt/ohpc/admin/images/rocky9.4` and reboot the login node with `sudo ssh login reboot`.

### Other notes

#### Confirmed working steps on SMS

sudo yum -y install fail2ban
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo nano /etc/fail2ban/jail.d/sshd.local

```
[sshd]
enabled = true
```

followed by:
```
sudo systemctl restart fail2ban
```

For the login node, needed to also do:
```
[user1@sms-0 ~]$ echo "drivers += kernel/net" | sudo tee -a /etc/warewulf/bootstrap.conf
[user1@sms-0 ~]$ sudo wwbootstrap `uname -r`
```
and reboot to get a better kernel.