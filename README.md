#  Tutorial_Practice

# Intro

## Build client VM
Go to use.jetstream-cloud.org

Start a new project, launch a new image based on 
the CentOS 7 Development GUI image.
- It might be better to have a multi-user client server set up.
This way we could give them an openrc as well. 

Talk about something here for ~10 min... basic intro stuff?

The openstack client *should* work there. 

Have folks create an openrc.sh with their training account
info. 

```
export OS_PROJECT_DOMAIN_NAME=tacc
export OS_USER_DOMAIN_NAME=tacc
export OS_PROJECT_NAME=tg-tra100001s
export OS_USERNAME=tg?????
export OS_PASSWORD=
export OS_AUTH_URL=
export OS_IDENTITY_API_VERSION=3
```

Make sure everyone has access to a working cmdline client - go through install steps if necessary. 
Check openrc.sh.

Have some basic openstack-client test command that everyone can confirm works for them.
Be sure they can get the image number that we'll use for the nodes:
```
openstack image list | grep Featured-Centos7
```

As a first step, show the security group that we'll use
(Since this is done on an allocation-wide basis, everyone trying to create it would fail)

```
openstack security group show  global-ssh
```

Next, we'll create an ssh key on the client, which will be added to all VMs
```
ssh-keygen -b 2048 -t rsa -f ${OS_USERNAME}-api-key -P ""
```

And add the public key to openstack - this will let you log in to the VMs you create.
```
openstack keypair create --public-key ${OS_USERNAME}-api-key.pub ${OS_USERNAME}-api-key
```

# Create the Private Network
```
openstack network create ${OS_USERNAME}-api-net
openstack subnet create --network ${OS_USERNAME}-api-net --subnet-range 10.0.0.0/24 ${OS_USERNAME}-api-subnet1
openstack subnet list
openstack router create ${OS_USERNAME}-api-router
openstack router add subnet ${OS_USERNAME}-api-router ${OS_USERNAME}-api-subnet1
openstack router set --external-gateway public ${OS_USERNAME}-api-router
openstack router show ${OS_USERNAME}-api-router
```

# Build Headnode VM

During this step, log in to 
```jblb.jetstream-cloud.org/dashboard```
with your tg???? id, to monitor your build progress on the Horizon interface.

First we'll create a VM to contain the head node. 

```
openstack server create --flavor m1.tiny  --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --security-group global-ssh --security-group cluster-internal --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-headnode 
```

Now, create a public IP for that server:
```
openstack floating ip create public
openstack server add floating ip ${OS_USERNAME}-headnode your.ip.number.here
```

While we wait, create a storage volume to mount on your headnode
```
openstack volume create --size 10 ${OS_USERNAME}-10GVolume

```

Where the vm-uid-number is the uid for the headnode.
```
openstack server add volume ${OS_USERNAME}-headnode ${OS_USERNAME}-10GVolume
```

Now, on your client machine, create a .ssh/config file in your home directory, and add the following:
```
Host headnode
 user centos
 Hostname your.headnode.ip.here
 Port 22
 IdentityFile /home/your-username/your-os-username-api-key
```

# Configure Headnode VM
ssh into your headnode machine 
```
ssh -i $your-key-name centos@server-public-ip
#Or, if you set up the above .ssh/config:
ssh headnode
```

Become root:
```
sudo su -
```

Create and ssh key on the headnode, as root:
```
ssh-keygen -b 2048 -t rsa
```
We'll use this to enable root access between nodes in the cluster, later.

Find the new volume on the headnode with:
```
dmesg | tail
```

Create a new partition with parted:
```
parted /dev/sdb
>mktable 
> type:gpt
>mkpart 
> name: export
> filesystem type: xfs
> start:0% 
> end:100%
>quit
mkfs.xfs /dev/sdb1
```

Now, find the UUID of your new partition, and mount:
```
ls -l /dev/disk/by-uuid
sudo vi /etc/fstab
#Add the line: 
#$UUID   /export   xfs    defaults   0 0
```

Now, we start installing software on the headnode! 


Note what the private IP is:
```
ip addr
```

```
yum install vim rsync epel-release openmpi openmpi-devel gcc gcc-c++ gcc-gfortran openssl-devel libxml2-devel boost-devel net-tools readline-devel pam-devel perl-ExtUtils-MakeMaker 
```

Edit /etc/exports to include (substitute the private IP of your headnode!):
```
 "/home 10.0.0.0/24(rw,no_root_squash)"
```

 Also, export the shared volume:
```
 "/export 10.0.0.0/24(rw,no_root_squash)"
```


Save and restart nfs, run exportfs. 
```
systemctl enable nfs-server nfs-lock nfs rpcbind nfs-idmap
systemctl start nfs-server nfs-lock nfs rpcbind nfs-idmap
```

Set ntp as a server on the private net only: 
edit /etc/ntpd.conf to include
```
# Permit access over internal cluster network
restrict 10.0.0.0 mask 255.255.255.0 nomodify notrap
```

And then restart:
```
systemctl restart ntpd
```

Now, add the OpenHPC Yum repository to your headnode

```
yum install https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm
```

Now, install the OpenHPC Slurm server package
```
yum install ohpc-slurm-server
```

Check that /etc/munge/munge.key exists:
```
ls /etc/munge/
```

# Build Compute Nodes

Now, we can create compute nodes attached ONLY to the private network.
Log out of your headnode machine, and back to the client.

Create two compute nodes as follows:
```
openstack server create --flavor m1.medium --security-group cluster-internal --security-group global-ssh --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-compute-0
openstack server create --flavor m1.medium --security-group cluster-internal --security-group global-ssh --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-compute-1
```

Check their assigned ip addresses with
```
openstack server show ${OS_USERNAME}-compute-0
openstack server show ${OS_USERNAME}-compute-1
```

Now, on your client machine, add the following in your .ssh/config:
```
Host compute-0
 user centos
 Hostname compute.0.ip.here
 Port 22
 ProxyCommand ssh -q -W %h:%p headnode
 IdentityFile /home/ecoulter/tg829096-api-key

Host compute-1
 user centos
 Hostname compute.1.ip.here
 Port 22
 ProxyCommand ssh -q -W %h:%p centos@headnode
 IdentityFile /home/ecoulter/tg829096-api-key
```
This will let you access your compute nodes without putting them on the
public internet.

Now, log back in to your headnode:

Create entries for these in /etc/hosts on the headnode:
```
compute.0.ip.here    compute-0  compute-0.novalocal
compute.1.ip.here    compute-1  compute-1.novalocal
```

Now, copy the root ssh public key from the headnode to the compute nodes.
```
headnode ~]# cat .ssh/id_rsa.pub #copy the output to your clipboard
client ~]# ssh compute-0
compute-0 ~]# sudo vi /root/.ssh/authorized_keys
client ~]# ssh compute-1
compute-1 ~]# sudo vi /root/.ssh/authorized_keys
```

# Configure Compute nodes/scheduler
In /etc/hosts, add entries for each of your VMs on the headnode:
```
$headnode-private-ip  headnode
$compute-0-private-ip  compute-0
$compute-1-private-ip  compute-1
```

Now, on each compute node,
in /etc/fstab, add the following line:
```
headnode.ip.goes.here:/home  /home  nfs  defaults 0 0
```

Be sure to allow selinux to use nfs home directories:
```
sudo setsebool -P use_nfs_home_dirs on
```

Double-check that this worked:
```
mount -a 
df -h
```

Now, as on the headnode, add the OpenHPC repository and install the ohpc-slurm-client.
```
yum install https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm
yum install ohpc-slurm-client
```

This will create a new munge key on the compute nodes, so you will have to copy over
the munge key from the headnode:
```
scp /etc/munge/munge.key compute-0:/etc/munge/
scp /etc/munge/munge.key compute-1:/etc/munge/
```

# Set up the Scheduler
Now, we need to edit the scheduler configuration file, /etc/slurm/slurm.conf
 - you'll have to either be root on the headnode, or use sudo.
```
ClusterName=test-cluster
ControlMachine=${OS_USERNAME}-headnode
...
FastSchedule=0
...
SlurmctldLogFile=/var/log/slurmctld.log
SlurmdLogFile=/var/log/slurmd.log
...
JobAcctGatherType=jobacct_gather/linux
JobAcctGatherFrequency=30
...
AccountingStorageType=accounting_storage/filetxt
AccountingStorageHost=headnode
AccountingStorageLoc=/var/log/slurmacct.log
...
# PLEASE REPLACE ${OS_USERNAME} WITH THE TEXT OF YOUR Openstack USERNAME!
NodeName=${OS_USERNAME}0compute-[0-1] State=UNKNOWN
#PartitionName=$name Nodes=ute-[0-1] Defult=YET MaxTime=2-00:00:00 State=UP
PartitionName=general Nodes=${OS_USERNAME}-compute-[0-1] Default=YES MaxTime=2-00:00:00 State=UP
```

Now, create the necessary files in /var/log/ and make sure they are owned by the 
slurm user:
```
touch /var/log/slurmctld.log
chown slurm:slurm /var/log/slurmctld.log
touch /var/log/slurmacct.log
chown slurm:slurm /var/log/slurmacct.log
```

Finally, start the munge and slurmctld services:
```
systemctl enable munge slurmctld
systemctl start munge slurmctld
```

Once you've finished that, scp the new slurm.conf to each compute node:
```
scp /etc/slurm/slurm.conf compute-0:/etc/slurm/
scp /etc/slurm/slurm.conf compute-1:/etc/slurm/
```

And start the services on the compute nodes:
```
ssh compute-0 'systemctl enable munge slurmd && systemctl start munge slurmd'
ssh compute-1 'systemctl enable munge slurmd && systemctl start munge slurmd'
```

Run sinfo and scontrol to see your new nodes:
```
sinfo
scontrol
```

They show up in state unknown - it's necessary when adding nodes to inform SLURM
that they are ready to accept jobs:
```
scontrol update NodeName=compute-[0-1] State=IDLE
```

So the current state should now be:
```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
general*     up 2-00:00:00      2  idle* compute-[0-1]
```

# Run some JOBS


# Conclusion
Scripted build show-off if we have time. 
Make sure people have links / contact points for future info.
\end{document}

