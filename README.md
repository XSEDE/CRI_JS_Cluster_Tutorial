#  Tutorial_Practice

# Intro

## Build client VM
Go to use.jetstream-cloud.org

Start a new project, launch a new image based on 
the CentOS 7 Development GUI image.
- It might be better to have a multi-user client server set up.
This way we could give them an openrc as well. 

Talk about something here for ~10 min.

The openstack client should work there. 

Have folks create an openrc.sh with their training account
info. 

Make sure everyone has access to a working cmdline client - go through install steps if necessary. 
Check openrc.sh.

Have some basic openstack-client test command that everyone can confirm works for them.

`openstack image list`.

As a first step, create a security group to allow ssh access to your VMs:

```
openstack security group create --description "ssh \& icmp enabled" global-ssh
openstack security group rule create --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0 global-ssh
openstack security group rule create --protocol icmp global-ssh
```

Next, we'll create an ssh key - feel free to use an existing key if you have one.
```
ssh-keygen -b 2048 -t rsa -f ${OS_PROJECT_NAME}-api-key -P ""
```

And add the public key to openstack - this will let you log in to the VMs you create.
```
openstack keypair create --public-key id_rsa.pub ${OS_PROJECT_NAME}-api-key
```

# Create the Private Network
```
openstack network create ${OS_PROJECT_NAME}-api-net
openstack subnet create --network ${OS_PROJECT_NAME}-api-net --subnet-range 10.0.0.0/24 ${OS_PROJECT_NAME}-api-subnet1
openstack subnet list
openstack router create ${OS_PROJECT_NAME}-api-router
openstack router add subnet ${OS_PROJECT_NAME}-api-router ${OS_PROJECT_NAME}-api-subnet1
openstack router set --external-gateway public ${OS_PROJECT_NAME}-api-router
openstack router show ${OS_PROJECT_NAME}-api-router
```



# Build Headnode VM
First we'll create a VM to contain the head node. 

```
openstack server create --flavor m1.small  --image "Centos 7 (7.3) Development GUI" --key-name ${OS_PROJECT_NAME}-api-key --security-group global-ssh --nic net-id=${OS_PROJECT_NAME}-api-net headnode
```

Now, create a public IP for that server:
```
openstack floating ip create public
openstack server add floating ip ${OS_PROJECT_NAME}-api-U-1 your.ip.number.here
SSH root@your.ip.number.here
```


```
`openstack volume create \verb--size 10 \$\{OS_PROJECT_NAME\}\verb-10GVolume`

```

Where the vm-uid-number is the uid for the headnode.
```
`openstack server add volume vm-uid-number volume-uid-number`
```

# Configure Headnode VM

Now, we start installing software on the headnode! 

ssh into your headnode machine 
```
ssh -i $your-key-name train-xx@server-public-ip
```

Note what the private IP is:
```
ip addr
```

```
yum install  "vim" "rsync" "epel-release""openmpi" "openmpi-devel"  "gcc" "gcc-c++" "gcc-gfortran" "openssl-devel" "libxml2-devel" "boost-devel" "net-tools" "readline-devel"  "pam-devel" "perl-ExtUtils-MakeMaker" 
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


 Save and restart nfs, exportfs. 

Set ntp as a server on the private net only: 
edit /etc/ntpd.conf to include
```
# Permit access over internal cluster network
restrict {{ internal_network }} mask 255.255.255.0 nomodify notrap
```

Now, add the OpenHPC Yum repository to your headnode

Create munge key.


# Build Compute Nodes

Now, we can create compute nodes attached ONLY to the private network:
```
openstack server create \
--flavor m1.medium \
--image "CentOS-7-x86_64-GenericCloud-1607" \
--key-name ${OS_PROJECT_NAME}-api-key \
--security-group global-ssh \
--nic net-id=${OS_PROJECT_NAME}-api-net \
compute-0
```

```
openstack server create \
--flavor m1.small \
--image "CentOS-7-x86_64-GenericCloud-1607" \
--key-name ${OS_PROJECT_NAME}-api-key \
--security-group global-ssh \
--nic net-id=${OS_PROJECT_NAME}-api-net
compute-1
```


# Configure Compute nodes/scheduler
In /etc/hosts, add entries for each of your VMs on the headnode:
```
$headnode-private-ip  headnode
$compute-0-private-ip  compute-0
$compute-1-private-ip  compute-1
```

From root on the headnode, run
ssh-copy-id compute-0 (This probably won't work w/out password login, actually...)
ssh-copy-id compute-1

In /etc/fstab, add the following lines:
(Replace 10.0.0.4 with the private ip of your headnode!)
```
"10.0.0.4:/N  /N  nfs  defaults 0 0"
"10.0.0.4:/home  /home  nfs  defaults 0 0"
```



# Run some JOBS
# Conclusion
Scripted build show-off if we have time. 
Make sure people have links / contact points for future info.
\end{document}

