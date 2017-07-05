#  Tutorial_Practice

# Access Openstack Client Server

ssh ${OS_USERNAME}@149.165.157.95

# Configure openstack client

First, edit the openrc.sh with your training account
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

```
pearc-clusters-server] --> openstack security group show global-ssh 
pearc-clusters-server] --> openstack security group show cluster-internal
```

Next, create an ssh key on the client, which will be added to all VMs
```
pearc-clusters-server] --> ssh-keygen -b 2048 -t rsa -f ${OS_USERNAME}-api-key -P ""
```

And add the public key to openstack - this will let you log in to the VMs you create.
```
pearc-clusters-server] --> openstack keypair create --public-key ${OS_USERNAME}-api-key.pub ${OS_USERNAME}-api-key
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

Now, on your client machine, create a .ssh/config file in your home directory, and add the following:
```
pearc-clusters-server] --> vim .ssh/config
#ssh config file:
Host headnode
 user centos
 Hostname YOUR-HEADNODE-IP
 Port 22
 IdentityFile /home/your-username/your-os-username-api-key
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

Set the hostname, to avoid confusion:
```
headnode] --> hostnamectl set-hostname headnode
```

Create an ssh key on the headnode, as root:
```
headnode] --> ssh-keygen -b 2048 -t rsa
```
We'll use this to enable root access between nodes in the cluster, later.

Note what the private IP is - it will be referred to later as 
$headnode-private-ip (in this example, it shows up at 10.0.0.1):
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
Find the new volume on the headnode with:
```
headnode] --> dmesg | tail
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
headnode] --> vim /etc/ntpd.conf
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
 ProxyCommand ssh -q -W %h:%p centos@headnode
 IdentityFile /home/OS_USERNAME/OS_USERNAME-api-key
```
This will let you access your compute nodes without putting them on the
public internet.

Now, log back in to your headnode, and
copy the root ssh public key from the headnode to the compute nodes.

---
**don't skip this step!**
---

```
pearc-clusters-server] --> ssh headnode
headnode] --> sudo su -
headnode] --> cat .ssh/id_rsa.pub #copy the output to your clipboard
pearc-clusters-server] --> ssh compute-0
compute-0 ~]# sudo vi /root/.ssh/authorized_keys #paste your key into this file
compute-0 ~]# cat -vTE /root/.ssh/authorized_keys #check that there are no newline '^M', tab '^I'
                                                 # characters or lines ending in '$'
                                                 #IF SO, REMOVE THEM! The ssh key must be on a single line
#Repeat for compute-1:
pearc-clusters-server] --> ssh compute-1
compute-1 ~]# sudo vi /root/.ssh/authorized_keys
compute-0 ~]# cat -vTE /root/.ssh/authorized_keys 
```

Confirm that as root on the headnode, you can ssh into each compute node:
```
pearc-clusters-server] --> ssh headnode
headnode] --> sudo su -
headnode] --> ssh compute-0
headnode] --> ssh compute-1
```

# Configure Compute Node Mounts:
In /etc/hosts, add entries for each of your VMs on the headnode:
```
headnode] --> vim /etc/hosts
HEADNODE-PRIVATE-IP  headnode
COMPUTE-0-PRIVATE-IP  compute-0
COMPUTE-1-PRIVATE-IP  compute-1
```

Now, ssh into each compute node, and perform the following steps to
mount the shared directories from the headnode:
setps on EACH compute node:
(Be sure you are ssh-ing as root!)
```
headnode] --> ssh compute-0
compute-0 ~]# mkdir /export
compute-0 ~]# vim /etc/fstab
#ADD these two lines; do NOT remove existing entries!
$headnode-private-ip:/home  /home  nfs  defaults 0 0
$headnode-private-ip:/export  /export  nfs  defaults 0 0
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

Follow the same steps for compute-1 now.

# Install and configure scheduler daemon on compute nodes

Now, as on the headnode, add the OpenHPC repository and install the ohpc-slurm-client to 
EACH compute node.
```
compute-0 ~]# yum install https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm
compute-0 ~]# yum install ohpc-slurm-client
```
Now, repeat the above on compute-1.

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
```
headnode] --> vim /etc/slurm.conf
ClusterName=test-cluster
# PLEASE REPLACE OS_USERNAME WITH THE TEXT OF YOUR Openstack USERNAME!
ControlMachine=OS_USERNAME-headnode
...
FastSchedule=0 #this allows SLURM to auto-detect hardware on compute nodes
...
# PLEASE REPLACE OS_USERNAME WITH THE TEXT OF YOUR Openstack USERNAME!
NodeName=OS_USERNAME-compute-[0-1] State=UNKNOWN
#PartitionName=$name Nodes=ute-[0-1] Defult=YET MaxTime=2-00:00:00 State=UP
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
headnode] --> ssh compute-0 'systemctl enable slurmctld'
headnode] --> ssh compute-0 'systemctl start slurmctld'
headnode] --> ssh compute-0 'systemctl status slurmctld'
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
headnode] --> scontrol update NodeName=compute-[0-1] State=IDLE
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
