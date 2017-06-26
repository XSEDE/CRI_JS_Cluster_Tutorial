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

Next, we'll create an ssh key on their client
```
ssh-keygen -b 2048 -t rsa -f ${OS_USERNAME}-api-key -P ""
```

And add the public key to openstack - this will let you log in to the VMs you create.
```
openstack keypair create --public-key ${OS_USERNAME}.pub ${OS_USERNAME}-api-key
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
openstack server create --flavor m1.tiny  --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --security-group global-ssh --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-headnode 
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
Host headnode
 user centos
 Hostname 149.165.156.205
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
> start:0% 
> end:100%
> fstype: xfs
>quit
mkfs.xfs /devsdb1
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
yum install munge munge-devel python-pip munge-libs
```

Edit /etc/exports to include (substitute the private IP of your headnode!):
```
 "/home 10.0.0.0/24(rw,no_root_squash)"
```
 Also, export the shared volume:
```
 "/N 10.0.0.0/24(rw,no_root_squash)"
```


Save and restart nfs, run exportfs. 

Set ntp as a server on the private net only: 
edit /etc/ntpd.conf to include
```
# Permit access over internal cluster network
restrict 10.0.0.0 mask 255.255.255.0 nomodify notrap
```

Now, add the OpenHPC Yum repository to your headnode

```
yum install https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm
```

Now, install the OpenHPC Slurm server package
```
yum install ohpc-slurm-server
```

Create munge key.
```
/usr/sbin/create-munge-key
```

# Build Compute Nodes

Now, we can create compute nodes attached ONLY to the private network:
```
openstack server create --flavor m1.medium  --security-group global-ssh --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-compute-0
openstack server create --flavor m1.medium --security-group global-ssh --image "JS-API-Featured-Centos7-Feb-7-2017" --key-name ${OS_USERNAME}-api-key --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-compute-1
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
 Hostname 10.0.0.8
 Port 22
 ProxyCommand ssh -q -W %h:%p headnode
 IdentityFile /home/ecoulter/tg829096-api-key

Host compute-1
 user centos
 Hostname 10.0.0.9
 Port 22
 ProxyCommand ssh -q -W %h:%p centos@headnode
 IdentityFile /home/ecoulter/tg829096-api-key
```

Create entries for these in /etc/hosts on the headnode:
```
10.0.0.8    compute-0  compute-0.jetstreamlocal
10.0.0.9    compute-1  compute-1.jetstreamlocal
```

Now, copy your ssh public key from the headnode to the compute nodes.
```
headnode ~]# cat .ssh/id_rsa.pub
client ~]# ssh compute-0
compute-0 ~]# vi .ssh/authorized_keys
client ~]# ssh compute-1
compute-1 ~]# vi .ssh/authorized_keys
```

# Configure Compute nodes/scheduler
In /etc/hosts, add entries for each of your VMs on the headnode:
```
$headnode-private-ip  headnode
$compute-0-private-ip  compute-0
$compute-1-private-ip  compute-1
```

Now, on each compute node,
in /etc/fstab, add the following lines:
(Replace 10.0.0.4 with the private ip of your headnode!)
```
10.0.0.4:/N  /N  nfs  defaults 0 0
10.0.0.4:/home  /home  nfs  defaults 0 0
```



# Run some JOBS
# Conclusion
Scripted build show-off if we have time. 
Make sure people have links / contact points for future info.
\end{document}

