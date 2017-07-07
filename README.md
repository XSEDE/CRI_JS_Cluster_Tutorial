#  Tutorial_Practice

# Access Openstack Client Server

To access the client server, use your provided OS_USERNAME and password,
and log in to
```
ssh ${OS_USERNAME}@149.165.157.95
```

You may experience a delay after typing in your password - this is normal!
Don't cancel your connection.

# Configure openstack client

First, double-check the openrc.sh with your training account
info - the file already exists in your home
directory:

```
pearc-clusters-server] --> cat ./openrc.sh
export OS_PROJECT_DOMAIN_NAME=tacc
export OS_USER_DOMAIN_NAME=tacc
export OS_PROJECT_NAME=tg-tra100001s
export OS_USERNAME=tg?????
export OS_PASSWORD=????
export OS_AUTH_URL=
export OS_IDENTITY_API_VERSION=3
```

Next, add these environment variables to your shell session:
```
pearc-clusters-server] --> source openrc.sh
```

Ensure that you have working openstack client access by running:
```
pearc-clusters-server] --> openstack image list | grep Featured-Centos7
```

As a first step, show the security groups that we'll use
 - normally, you would have to create this when first using an allocation.
By DEFAULT, the security groups on Jetstream are CLOSED - this is the opposite
of how firewalls typically work (completely OPEN by default). 
If you create a host on a new allocation without adding it to a security group
that allows access to some ports, you will not be able to use it!

```
pearc-clusters-server] --> openstack security group show global-ssh 
pearc-clusters-server] --> openstack security group show cluster-internal
```

Next, create an ssh key on the client, which will be added to all VMs
```
pearc-clusters-server] --> ssh-keygen -b 2048 -t rsa -f ${OS_USERNAME}-api-key -P ""
#just accepting the defaults (hit Enter) is fine for this tutorial!
```

And add the public key to openstack - this will let you log in to the VMs you create.
```
pearc-clusters-server] --> openstack keypair create --public-key ${OS_USERNAME}-api-key.pub ${OS_USERNAME}-api-key
```

Show your openstack keys via:
```
openstack keypair list
```

If you want to be 100% sure, you can show the fingerprint of your key with
```
ssh-keygen -lf ${OS_USERNAME}-api-key
```

## Create the Private Network
```
pearc-clusters-server] --> openstack network create ${OS_USERNAME}-api-net
pearc-clusters-server] --> openstack subnet create --network ${OS_USERNAME}-api-net --subnet-range 10.0.0.0/24 ${OS_USERNAME}-api-subnet1
pearc-clusters-server] --> openstack subnet list
pearc-clusters-server] --> openstack router create ${OS_USERNAME}-api-router
pearc-clusters-server] --> openstack router add subnet ${OS_USERNAME}-api-router ${OS_USERNAME}-api-subnet1
pearc-clusters-server] --> openstack router set --external-gateway public ${OS_USERNAME}-api-router
pearc-clusters-server] --> openstack router show ${OS_USERNAME}-api-router
```

# Build Headnode VM

During this step, log in to 
```jblb.jetstream-cloud.org/dashboard```

with your tg???? id, to monitor your build progress on the Horizon interface.
You will also be able to view other trainees instances and networks - **PLEASE do not delete 
or modify anything that isn't yours!**

First we'll create a VM to contain the head node. 

```
pearc-clusters-server] --> openstack server create --flavor m1.tiny  --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --security-group global-ssh --security-group cluster-internal --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-headnode 
```

Now, create a public IP for that server:
```
pearc-clusters-server] --> openstack floating ip create public
pearc-clusters-server] --> openstack server add floating ip ${OS_USERNAME}-headnode your.ip.number.here
```

While we wait, create a storage volume to mount on your headnode
```
pearc-clusters-server] --> openstack volume create --size 10 ${OS_USERNAME}-10GVolume

```

Now, add the new storage device to your headnode VM:
```
pearc-clusters-server] --> openstack server add volume ${OS_USERNAME}-headnode ${OS_USERNAME}-10GVolume
```

Now, on your client machine, create a .ssh directory in your home directory, and add the following:
```
pearc-clusters-server] --> mkdir -m 0700 .ssh
pearc-clusters-server] --> vim .ssh/config
#ssh config file:
Host headnode
 user centos
 Hostname YOUR-HEADNODE-IP
 Port 22
 IdentityFile /home/your-username/your-os-username-api-key
```
Make sure the permissions on .ssh are 700!
```
pearc-clusters-server] --> ls -ld .ssh
pearc-clusters-server] --> chmod 0700 .ssh
```

# Configure Headnode VM
ssh into your headnode machine 
```
pearc-clusters-server] --> ssh headnode
#Or, if you didn't set up the above .ssh/config:
pearc-clusters-server] --> ssh -i YOUR-KEY-NAME centos@YOUR-HEADNODE-PUBLIC-IP
```

Become root: (otherwise, you'll have to preface much of the following with sudo)
```
headnode] --> sudo su -
```

Create an ssh key on the headnode, as root:
```
headnode] --> ssh-keygen -b 2048 -t rsa
#just accepting the defaults (hit Enter) is fine for this tutorial!
```
We'll use this to enable root access between nodes in the cluster, later.

Note what the private IP is - it will be referred to later as 
HEADNODE-PRIVATE-IP (in this example, it shows up at 10.0.0.1):
``` 
headnode] --> ip addr
...
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000 qdisc pfifo_fast state UP qlen 1000
    link/ether fa:16:3e:ef:7b:21 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.1/24 brd 172.26.37.255 scope global dynamic eth0
       valid_lft 202sec preferred_lft 202sec
    inet6 fe80::f816:3eff:feef:7b21/64 scope link 
       valid_lft forever preferred_lft forever
...
```

Install useful software:
```
headnode] --> yum install vim rsync epel-release openmpi openmpi-devel gcc gcc-c++ gcc-gfortran openssl-devel libxml2-devel boost-devel net-tools readline-devel pam-devel perl-ExtUtils-MakeMaker 
```
Find the new volume on the headnode with (most likely it will mount as sdb):
```
headnode] --> dmesg | grep sd
[    1.715421] sd 2:0:0:0: [sda] 16777216 512-byte logical blocks: (8.58 GB/8.00 GiB)
[    1.718439] sd 2:0:0:0: [sda] Write Protect is off
[    1.720066] sd 2:0:0:0: [sda] Mode Sense: 63 00 00 08
[    1.720455] sd 2:0:0:0: [sda] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
[    1.725878]  sda: sda1
[    1.727563] sd 2:0:0:0: [sda] Attached SCSI disk
[    2.238056] XFS (sda1): Mounting V5 Filesystem
[    2.410020] XFS (sda1): Ending clean mount
[    7.997131] Installing knfsd (copyright (C) 1996 okir@monad.swb.de).
[    8.539042] sd 2:0:0:0: Attached scsi generic sg0 type 0
[    8.687877] fbcon: cirrusdrmfb (fb0) is primary device
[    8.719492] cirrus 0000:00:02.0: fb0: cirrusdrmfb frame buffer device
[  246.622485] sd 2:0:0:1: Attached scsi generic sg1 type 0
[  246.633569] sd 2:0:0:1: [sdb] 20971520 512-byte logical blocks: (10.7 GB/10.0 GiB)
[  246.667567] sd 2:0:0:1: [sdb] Write Protect is off
[  246.667923] sd 2:0:0:1: [sdb] Mode Sense: 63 00 00 08
[  246.678696] sd 2:0:0:1: [sdb] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
[  246.793574] sd 2:0:0:1: [sdb] Attached SCSI disk
```

Create a new filesystem on the device:
```
headnode] --> mkfs.xfs /dev/sdb
```

Now, find the UUID of your new filesystem, add it to fstab, and mount:
```
headnode] --> ls -l /dev/disk/by-uuid
UUID_OF_ROOT  /dev/sda
UUID_OF_NEW   /dev/sdb
headnode] --> vi /etc/fstab
#Add the line: 
UUID=UUID_OF_NEW   /export   xfs    defaults   0 0
headnode] --> mkdir /export
headnode] --> mount -a
```

Edit /etc/exports to include (substitute the private IP of your headnode!)
entries for /home and /export
```
headnode] --> vim /etc/exports
/home 10.0.0.0/24(rw,no_root_squash)
/export 10.0.0.0/24(rw,no_root_squash)
```


Save and restart nfs, run exportfs. 
```
headnode] --> systemctl enable nfs-server nfs-lock nfs rpcbind nfs-idmap
headnode] --> systemctl start nfs-server nfs-lock nfs rpcbind nfs-idmap
```


Set ntp as a server on the private net only: 
edit /etc/ntp.conf to include
```
headnode] --> vim /etc/ntp.conf
# Permit access over internal cluster network
restrict 10.0.0.0 mask 255.255.255.0 nomodify notrap
```

And then restart:
```
headnode] --> systemctl restart ntpd
```

Now, add the OpenHPC Yum repository to your headnode

```
headnode] --> yum install https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm
```

Now, install the OpenHPC Slurm server package
```
headnode] --> yum install ohpc-slurm-server
```

Check that /etc/munge/munge.key exists:
```
headnode] --> ls /etc/munge/
```

# Build Compute Nodes

Now, we can create compute nodes attached ONLY to the private network.

LOG OUT OF YOUR HEADNODE MACHINE, and back to the client.

Create two compute nodes as follows:
```
pearc-clusters-server] --> openstack server create --flavor m1.medium --security-group cluster-internal --security-group global-ssh --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-compute-0
pearc-clusters-server] --> openstack server create --flavor m1.medium --security-group cluster-internal --security-group global-ssh --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-compute-1
```

Check their assigned ip addresses with
```
pearc-clusters-server] --> openstack server show ${OS_USERNAME}-compute-0
pearc-clusters-server] --> openstack server show ${OS_USERNAME}-compute-1
```

Now, on your client machine, add the following in your .ssh/config:
```
pearc-clusters-server] --> vim .ssh/config
#REPLACE OS_USERNAME with your OPENSTACK USER NAME! (tg455???)
Host compute-0
 user centos
 Hostname $your.compute.0.ip
 Port 22
 ProxyCommand ssh -q -W %h:%p headnode
 IdentityFile /home/OS_USERNAME/OS_USERNAME-api-key

#REPLACE OS_USERNAME with your OPENSTACK USER NAME! (tg455???)
Host compute-1
 user centos
 Hostname $your.compute.1.ip
 Port 22
 ProxyCommand ssh -q -W %h:%p headnode
 IdentityFile /home/OS_USERNAME/OS_USERNAME-api-key
```
This will let you access your compute nodes without putting them on the
public internet.


Now, log back in to your headnode, 
add the compute nodes to /etc/hosts, and
copy the root ssh public key from the headnode to the compute nodes.

---
**don't skip this step!**
---

In /etc/hosts, add entries for each of your VMs on the headnode:
```
headnode] --> vim /etc/hosts
HEADNODE-PRIVATE-IP  headnode
COMPUTE-0-PRIVATE-IP  compute-0
COMPUTE-1-PRIVATE-IP  compute-1
```
---
**ESPECIALLY don't skip this step!**
---

```
pearc-clusters-server] --> ssh headnode
headnode] --> sudo su -
headnode] --> cat .ssh/id_rsa.pub #copy the output to your clipboard
headnode] --> exit
pearc-clusters-server] --> ssh compute-0
compute-0 ~]# sudo vi /root/.ssh/authorized_keys #paste your key into this file
compute-0 ~]# sudo cat -vTE /root/.ssh/authorized_keys #check that there are no newline '^M', tab '^I'
                                                 # characters or lines ending in '$'
                                                 #IF SO, REMOVE THEM! The ssh key must be on a single line
compute-0 ~]# exit

#Repeat for compute-1:
pearc-clusters-server] --> ssh compute-1
compute-1 ~]# sudo vi /root/.ssh/authorized_keys
compute-0 ~]# sudo cat -vTE /root/.ssh/authorized_keys 
```

Confirm that as root on the headnode, you can ssh into each compute node:
```
pearc-clusters-server] --> ssh headnode
headnode] --> sudo su -
headnode] --> ssh compute-0
headnode] --> ssh compute-1
```

# Configure Compute Node Mounts:

Now, ssh into each compute node, and perform the following steps to
mount the shared directories from the headnode:
setps on EACH compute node:
(Be sure you are ssh-ing as root!)
```
headnode] --> ssh compute-0
compute-0 ~]# mkdir /export
compute-0 ~]# vi /etc/fstab
#ADD these two lines; do NOT remove existing entries!
HEADNODE-PRIVATE-IP:/home  /home  nfs  defaults 0 0
HEADNODE-PRIVATE-IP:/export  /export  nfs  defaults 0 0
```

Be sure to allow selinux to use nfs home directories:
```
compute-0 ~]# setsebool -P use_nfs_home_dirs on
```

Double-check that this worked:
```
compute-0 ~]# mount -a 
compute-0 ~]# df -h
```

---
**Follow the same steps for compute-1 now.**
---

# Install and configure scheduler daemon on compute nodes

Now, as on the headnode, add the OpenHPC repository and install the ohpc-slurm-client to 
EACH compute node.
```
compute-0 ~]# yum install https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm
compute-0 ~]# yum install ohpc-slurm-client openmpi openmpi-devel hwloc-libs
```

---
**Now, repeat the above on compute-1.**
---

This will create a new munge key on the compute nodes, so you will have to copy over
the munge key from the headnode:
```
headnode] --> scp /etc/munge/munge.key compute-0:/etc/munge/
headnode] --> scp /etc/munge/munge.key compute-1:/etc/munge/
```

# Set up the Scheduler
Now, we need to edit the scheduler configuration file, /etc/slurm/slurm.conf
 - you'll have to either be root on the headnode, or use sudo.
Change the lines below as shown here:

**Note: edit these lines, do not copy-paste this at the end!**

Blank lines indicate content to be skipped.
```
headnode] --> vim /etc/slurm/slurm.conf
ClusterName=test-cluster
# PLEASE REPLACE OS_USERNAME WITH THE TEXT OF YOUR Openstack USERNAME!
ControlMachine=OS_USERNAME-headnode

FastSchedule=0 #this allows SLURM to auto-detect hardware on compute nodes

# PLEASE REPLACE OS_USERNAME WITH THE TEXT OF YOUR Openstack USERNAME!
NodeName=OS_USERNAME-compute-[0-1] State=UNKNOWN
#PartitionName=$name Nodes=compute-[0-1] Default=YET MaxTime=2-00:00:00 State=UP
PartitionName=general Nodes=OS_USERNAME-compute-[0-1] Default=YES MaxTime=2-00:00:00 State=UP
```

Now, check the necessary files in /var/log/ and make sure they are owned by the 
slurm user:
```
headnode] --> touch /var/log/slurmctld.log
headnode] --> chown slurm:slurm /var/log/slurmctld.log
headnode] --> touch /var/log/slurmacct.log
headnode] --> chown slurm:slurm /var/log/slurmacct.log
```

Finally, start the munge and slurmctld services:
```
headnode] --> systemctl enable munge 
headnode] --> systemctl start munge 
headnode] --> systemctl enable slurmctld 
headnode] --> systemctl start slurmctld 
```

If slurmctld fails to start, check the following for useful messages:
```
headnode] --> systemctl -l status slurmctld
headnode] --> journalctl -xe
headnode] --> less /var/log/slurmctld.log
```

Once you've finished that, scp the new slurm.conf to each compute node:
(slurm requires that all nodes have the same slurm.conf file!)
```
headnode] --> scp /etc/slurm/slurm.conf compute-0:/etc/slurm/
headnode] --> scp /etc/slurm/slurm.conf compute-1:/etc/slurm/
```

Try remotely starting the services on the compute nodes:
(as root on the headnode)
```
headnode] --> ssh compute-0 'systemctl enable munge'
headnode] --> ssh compute-0 'systemctl start munge'
headnode] --> ssh compute-0 'systemctl status munge'
headnode] --> ssh compute-0 'systemctl enable slurmd'
headnode] --> ssh compute-0 'systemctl start slurmd'
headnode] --> ssh compute-0 'systemctl status slurmd'
```
As usual, repeat for compute-1

Run sinfo and scontrol to see your new nodes:
```
headnode] --> sinfo
headnode] --> sinfo --long --Node #sometimes a more usful format
headnode] --> scontrol show node  # much more detailed 
```

They show up in state unknown - it's necessary when adding nodes to inform SLURM
that they are ready to accept jobs:
```
headnode] --> scontrol update NodeName=OS_USERNAME-compute-[0-1] State=IDLE
```

So the current state should now be:
```
headnode] --> sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
general*     up 2-00:00:00      2  idle* compute-[0-1]
```

# Run some JOBS
On the headnode, as the centOS user, you will need to enable ssh access for yourself
across the cluster! 
Create an ssh key, and add it to authorized_keys. Since /home is mounted
on all nodes, this is enough to enable access to the compute nodes!
```
headnode] centos --> ssh-keygen -t rsa -b 2048
#just accepting the defaults (hit Enter) is fine for this tutorial!
headnode] centos --> cat .ssh/id_rsa.pub >> .ssh/authorized_keys
headnode] centos --> ssh compute-0 #just as a test
```

Now, create a simple SLURM batch script:
```
headnode] centos --> vim slurm_ex.job
#!/bin/bash
#SBATCH -N 2 #ask for 2 nodes
#SBATCH -n 4 #ask for 4 processes per node
#SBATCH -o nodes.out #redirect output to nodes.out
#SBATCH --time 05:00 #ask for 5 min of runtime

hostname 
srun -l hostname #srun runs the command on EACH node in the job allocation
sleep 30 # keep this in the queue long enough to see it!


headnode] centos --> sbatch slurm_ex.job  #output will be the job id number
2
headnode] centos --> squeue  #show the job queue
headnode] centos --> scontrol show job 2  #more detailed information
```

You can also run mpi jobs! Just be sure to include
```
module load mpi/openmpi-x86_64
```
before any mpirun commands. For a simple example, add
```
mpirun hostname
```
at the end of your slurm_ex.job, and resubmit. 
How does the output differ from before?
Slurm provides the correct environment variables to MPI
to run tasks on each available thread as needed.
