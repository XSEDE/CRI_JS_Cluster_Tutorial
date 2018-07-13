#  Tutorial_Practice
<!--
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
pearc-clusters-server]$ cat ./openrc.sh
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
pearc-clusters-server]$ source openrc.sh
```

Ensure that you have working openstack client access by running:
```
pearc-clusters-server]$ openstack image list | grep Featured-Centos7
```

As a first step, show the security groups that we'll use
 - normally, you would have to create this when first using an allocation.
By DEFAULT, the security groups on Jetstream are CLOSED - this is the opposite
of how firewalls typically work (completely OPEN by default). 
If you create a host on a new allocation without adding it to a security group
that allows access to some ports, you will not be able to use it!

```
pearc-clusters-server]$ openstack security group show global-ssh 
pearc-clusters-server]$ openstack security group show cluster-internal
```

Next, create an ssh key on the client, which will be added to all VMs
```
pearc-clusters-server]$ ssh-keygen -b 2048 -t rsa -f ${OS_USERNAME}-api-key -P ""
#just accepting the defaults (hit Enter) is fine for this tutorial!
```

And add the public key to openstack - this will let you log in to the VMs you create.
```
pearc-clusters-server]$ openstack keypair create --public-key ${OS_USERNAME}-api-key.pub ${OS_USERNAME}-api-key
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
pearc-clusters-server]$ openstack network create ${OS_USERNAME}-api-net
pearc-clusters-server]$ openstack subnet create --network ${OS_USERNAME}-api-net --subnet-range 10.0.0.0/24 ${OS_USERNAME}-api-subnet1
pearc-clusters-server]$ openstack subnet list
pearc-clusters-server]$ openstack router create ${OS_USERNAME}-api-router
pearc-clusters-server]$ openstack router add subnet ${OS_USERNAME}-api-router ${OS_USERNAME}-api-subnet1
pearc-clusters-server]$ openstack router set --external-gateway public ${OS_USERNAME}-api-router
pearc-clusters-server]$ openstack router show ${OS_USERNAME}-api-router
```

# Build Headnode VM

During this step, log in to 
```jblb.jetstream-cloud.org/dashboard```

with your tg???? id, to monitor your build progress on the Horizon interface.
You will also be able to view other trainees instances and networks - **PLEASE do not delete 
or modify anything that isn't yours!**

First we'll create a VM to contain the head node. 

```
pearc-clusters-server]$ openstack server create --flavor m1.tiny  --image "JS-API-Featured-Centos7-Jul-2-2018" --key-name ${OS_USERNAME}-api-key --security-group global-ssh --security-group cluster-internal --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-headnode 
```

Now, create a public IP for that server:
```
pearc-clusters-server]$ openstack floating ip create public
pearc-clusters-server]$ openstack server add floating ip ${OS_USERNAME}-headnode your.ip.number.here
```

While we wait, create a storage volume to mount on your headnode
```
pearc-clusters-server]$ openstack volume create --size 10 ${OS_USERNAME}-10GVolume

```

Now, add the new storage device to your headnode VM:
```
pearc-clusters-server]$ openstack server add volume ${OS_USERNAME}-headnode ${OS_USERNAME}-10GVolume
```

Now, on your client machine, create a .ssh directory in your home directory, and add the following:
```
pearc-clusters-server]$ mkdir -m 0700 .ssh
pearc-clusters-server]$ vim .ssh/config
#ssh config file:
Host headnode
 user centos
 Hostname YOUR-HEADNODE-IP
 Port 22
 IdentityFile /home/your-username/your-os-username-api-key
```
Make sure the permissions on .ssh are 700!
```
pearc-clusters-server]$ ls -ld .ssh
pearc-clusters-server]$ chmod 0700 .ssh
```

# Configure Headnode VM
ssh into your headnode machine 
```
pearc-clusters-server]$ ssh headnode
#Or, if you didn't set up the above .ssh/config:
pearc-clusters-server]$ ssh -i YOUR-KEY-NAME centos@YOUR-HEADNODE-PUBLIC-IP
```

Become root: (otherwise, you'll have to preface much of the following with sudo)
```
headnode]$ sudo su -
```

WE WILL START FROM HERE, IN 2018!
-->
Create an ssh key on the headnode, as root:
```
headnode]$ ssh-keygen -b 2048 -t rsa
#just accepting the defaults (hit Enter) is fine for this tutorial!
```
We'll use this to enable root access between nodes in the cluster, later.

Note what the private IP is - it will be referred to later as 
HEADNODE-PRIVATE-IP (in this example, it shows up at 10.0.0.1):
``` 
headnode]$ ip addr
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
headnode]$ yum install vim rsync epel-release net-tools 
```

###Just for today, we'll install the openstack client:
```
headnode] root$ pip install python-openstackclient
```

<!---
Find the new volume on the headnode with (most likely it will mount as sdb):
```
headnode]$ dmesg | grep sd
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
headnode]$ mkfs.xfs /dev/sdb
```

Now, find the UUID of your new filesystem, add it to fstab, and mount:
```
headnode]$ ls -l /dev/disk/by-uuid
UUID_OF_ROOT  /dev/sda
UUID_OF_NEW   /dev/sdb
headnode]$ vi /etc/fstab
#Add the line: 
UUID=UUID_OF_NEW   /export   xfs    defaults   0 0
headnode]$ mkdir /export
headnode]$ mount -a
```

Edit /etc/exports to include (substitute the private IP of your headnode!)
entries for /home and /export
```
headnode]$ vim /etc/exports
/home 10.0.0.0/24(rw,no_root_squash)
/export 10.0.0.0/24(rw,no_root_squash)
```


Save and restart nfs, run exportfs. 
```
headnode]$ systemctl enable nfs-server nfs-lock nfs rpcbind nfs-idmap
headnode]$ systemctl start nfs-server nfs-lock nfs rpcbind nfs-idmap
```
-->
Set ntp as a server on the private net only: 
edit /etc/chrony.conf to include
```
headnode]$ vim /etc/chrony.conf
# Permit access over internal cluster network
allow 10.0.0.0/24
```

And then restart:
```
headnode]$ systemctl restart chronyd
```

Now, add the OpenHPC Yum repository to your headnode

```
headnode]$ yum install https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm
```

Now, install the OpenHPC Slurm server package
```
headnode]$ yum install -y ohpc-slurm-server
```

Check that /etc/munge/munge.key exists:
```
headnode]$ ls /etc/munge/
```

# Build Compute Nodes

Now, we can create compute nodes attached ONLY to the private network.

LOG OUT OF YOUR HEADNODE MACHINE, and back to the client.

Create two compute nodes as follows:
```
pearc-clusters-server]$ openstack server create --flavor m1.medium --security-group cluster-internal --security-group global-ssh --image "JS-API-Featured-Centos7-Jul-2-2018" --key-name ${OS_USERNAME}-api-key --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-compute-0
pearc-clusters-server]$ openstack server create --flavor m1.medium --security-group cluster-internal --security-group global-ssh --image "JS-API-Featured-Centos7-Jul-2-2018" --key-name ${OS_USERNAME}-api-key --nic net-id=${OS_USERNAME}-api-net ${OS_USERNAME}-compute-1
```
Take note of how long this takes.

Check their assigned ip addresses with
```
pearc-clusters-server]$ openstack server show ${OS_USERNAME}-compute-0
pearc-clusters-server]$ openstack server show ${OS_USERNAME}-compute-1
```

Now, on your client machine, add the following in your .ssh/config:
```
pearc-clusters-server]$ vim .ssh/config
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
headnode]$ vim /etc/hosts
HEADNODE-PRIVATE-IP  headnode
COMPUTE-0-PRIVATE-IP  compute-0
COMPUTE-1-PRIVATE-IP  compute-1
```
---
**ESPECIALLY don't skip this step!**
---

```
pearc-clusters-server]$ ssh headnode
headnode]$ sudo su -
headnode]$ cat .ssh/id_rsa.pub #copy the output to your clipboard
headnode]$ exit
pearc-clusters-server]$ ssh compute-0
compute-0 ~]# sudo vi /root/.ssh/authorized_keys #paste your key into this file
compute-0 ~]# sudo cat -vTE /root/.ssh/authorized_keys #check that there are no newline '^M', tab '^I'
                                                 # characters or lines ending in '$'
                                                 #IF SO, REMOVE THEM! The ssh key must be on a single line
compute-0 ~]# exit

#Repeat for compute-1:
pearc-clusters-server]$ ssh compute-1
compute-1 ~]# sudo vi /root/.ssh/authorized_keys
compute-0 ~]# sudo cat -vTE /root/.ssh/authorized_keys 
```

Confirm that as root on the headnode, you can ssh into each compute node:
```
pearc-clusters-server]$ ssh headnode
headnode]$ sudo su -
headnode]$ ssh compute-0
headnode]$ ssh compute-1
```

# Configure Compute Node Mounts:

Now, ssh into EACH compute node, and perform the following steps to
mount the shared directories from the headnode:
(Be sure you are ssh-ing as root!)
```
headnode]$ ssh compute-0
compute-0 ~]# mkdir /export
compute-0 ~]# vi /etc/fstab
#ADD these two lines; do NOT remove existing entries!
HEADNODE-PRIVATE-IP:/home  /home  nfs  defaults,nofail 0 0
HEADNODE-PRIVATE-IP:/export  /export  nfs  defaults,nofail 0 0
HEADNODE-PRIVATE-IP:/opt/ohpc/pub  /opt/ohpc/pub  nfs  defaults,nofail 0 0
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
compute-0 ~]# yum install ohpc-slurm-client hwloc-libs
```

---
**Now, repeat the above on compute-1.**
---

This will create a new munge key on the compute nodes, so you will have to copy over
the munge key from the headnode:
```
headnode]$ scp /etc/munge/munge.key compute-0:/etc/munge/
headnode]$ scp /etc/munge/munge.key compute-1:/etc/munge/
```

# Set up the Scheduler
Now, we need to edit the scheduler configuration file, /etc/slurm/slurm.conf
 - you'll have to either be root on the headnode, or use sudo.
Change the lines below as shown here:

**Note: edit these lines, do not copy-paste this at the end!**

Blank lines indicate content to be skipped.
```
headnode]$ vim /etc/slurm/slurm.conf
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
headnode]$ touch /var/log/slurmctld.log
headnode]$ chown slurm:slurm /var/log/slurmctld.log
headnode]$ touch /var/log/slurmacct.log
headnode]$ chown slurm:slurm /var/log/slurmacct.log
```

Finally, start the munge and slurmctld services:
```
headnode]$ systemctl enable munge 
headnode]$ systemctl start munge 
headnode]$ systemctl enable slurmctld 
headnode]$ systemctl start slurmctld 
```

If slurmctld fails to start, check the following for useful messages:
```
headnode]$ systemctl -l status slurmctld
headnode]$ journalctl -xe
headnode]$ less /var/log/slurmctld.log
```

Once you've finished that, scp the new slurm.conf to each compute node:
(slurm requires that all nodes have the same slurm.conf file!)
```
headnode]$ scp /etc/slurm/slurm.conf compute-0:/etc/slurm/
headnode]$ scp /etc/slurm/slurm.conf compute-1:/etc/slurm/
```

Try remotely starting the services on the compute nodes:
(as root on the headnode)
```
headnode]$ ssh compute-0 'systemctl enable munge'
headnode]$ ssh compute-0 'systemctl start munge'
headnode]$ ssh compute-0 'systemctl status munge'
headnode]$ ssh compute-0 'systemctl enable slurmd'
headnode]$ ssh compute-0 'systemctl start slurmd'
headnode]$ ssh compute-0 'systemctl status slurmd'
```
As usual, repeat for compute-1

Run sinfo and scontrol to see your new nodes:
```
headnode]$ sinfo
headnode]$ sinfo --long --Node #sometimes a more usful format
headnode]$ scontrol show node  # much more detailed 
```

They show up in state unknown or drain - it's necessary when adding nodes to inform SLURM
that they are ready to accept jobs:
```
headnode]$ scontrol update NodeName=OS_USERNAME-compute-[0-1] State=IDLE
```

So the current state should now be:
```
headnode]$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
general*     up 2-00:00:00      2  idle* compute-[0-1]
```

# Run some Jobs
On the headnode, as the centOS user, you will need to enable ssh access for yourself
across the cluster! 
Create an ssh key, and add it to authorized_keys. Since /home is mounted
on all nodes, this is enough to enable access to the compute nodes!
```
headnode] centos$ ssh-keygen -t rsa -b 2048
#just accepting the defaults (hit Enter) is fine for this tutorial!
headnode] centos$ cat .ssh/id_rsa.pub >> .ssh/authorized_keys
headnode] centos$ ssh compute-0 #just as a test
```

Now, create a simple SLURM batch script:
```
headnode] centos$ vim slurm_ex.job
#!/bin/bash
#SBATCH -N 2 #ask for 2 nodes
#SBATCH -n 4 #ask for 4 processes per node
#SBATCH -o nodes_%A.out #redirect output to nodes_$JOB-NUMBER.out
#SBATCH --time 05:00 #ask for 5 min of runtime

hostname 
srun -l hostname #srun runs the command on EACH node in the job allocation
sleep 30 # keep this in the queue long enough to see it!


headnode] centos$ sbatch slurm_ex.job  #output will be the job id number
2
headnode] centos$ squeue  #show the job queue
headnode] centos$ scontrol show job 2  #more detailed information
```

# Set up the Modules system

Now that you've got a working scheduler, time to add some interesting software. 
For the sake of usability, we're going to use a modules system, to keep track
of different versions, compilers, etc. 
```
headnode] root$ yum install lmod-ohpc
```
Repeat the same on your compute nodes:
```
headnode] root$ ssh ${OS_USERNAME}-compute-0 'yum install -y lmod-ohpc'
headnode] root$ ssh ${OS_USERNAME}-compute-1 'yum install -y lmod-ohpc'
```

This sets you up with the 'lmod' module system.
(For more info, see [the site at TACC](https://www.tacc.utexas.edu/research-development/tacc-projects/lmod))

Right now, you won't have many modules available, but you can view them with
```
headnode] centos$ modules avail
```

The modulefiles from OpenHPC are installed in 
```
/opt/ohpc/pub/modulefiles
```
which is shared across the cluster, so you'll only need to modify them on the headnode.

# Install Compilers and OpenMPI

Before we have software, we'll need compilers! OpenHPC includes a variety
of compiler packages, which is especially useful in a research environment. 

For example:
```
yum list gnu*ohpc
```
will show two different versions of the gnu compilers.

We'll use the smaller of the two, and pull in the openmpi compilers as well:
```
headnode] root$ yum install gnu-complers-ohpc openmpi-gnu-ohpc
```

Notice there are different versions of openmpi as well:
```
yum list openmpi*ohpc
```

Now, you should see a 'gnu/$version' module. Load it with
```
headnode] centos$ module load gnu
```

This will make the appropriate openmpi module available as well,
visible via 
```
module avail
```

The environment modules system sets up a heirarchy so that packages
are only available under the same root as their compilers, to avoid
confusion when dealing with many different versions of software.

With those modules installed, you can now run (boring) mpi jobs.
Just be sure to include

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

# Build some Scientific Software with Spack 

In order to run something more interesting, let's build some software!

Spack is a package management tool designed specifically to ease the 
burden of HPC admins who need to provide a wide variety of community
software (and different versions for every different research group!).

Install via:
```
headnode] root$ yum install spack-ohpc
```

The spack configuration needs some editing - in 
/opt/ohpc/admin/spack/0.11.2/defaults/etc/spack/config.yaml
and
/opt/ohpc/admin/spack/0.11.2/defaults/etc/spack/modules.yaml

in order to be OpenHPC-friendly. 

Change the following two lines in config.yaml:
```
...
  install_tree: /opt/ohpc/pub/spack
...
    tcl:    /opt/ohpc/pub/modulefiles/spack
...
```
Be sure to preserve the whitespace!
We'll just use the default tcl modules for now.

To start using spack, as root, source the spack environment:
```
headnode] root$ . /opt/ohpc/admin/spack/0.11.2/share/spack/setup-env.sh
```

Now, let's add our new compilers to the spack environment. 
Make sure the gnu and openmpi modules are loaded 
(check this via `module list`), and run
```
headnode] root$ spack compiler find
```

In order to use the proper libraries, we also need to add the 
compilers to the spack config. Add the name of the gnu module to the
'modules' line for the gnu 5.4.0 compiler in
/root/.spack/linux/compilers.yaml 
```
...
    module: [gnu/5.4.0]
...
```

Finally, we can build some software! 
Spack has an enormous library of tools available. We'll install a 
standard molecular dynamics code as an example:
```
headnode] root$ spack install lammps+molecule % gcc@5.4.0
```

Spack install syntax follows a format like
```
install package_name+package-variants@package_version %compiler_name@compiler_version
```
where everything but the package name is optional. 
For more detailed info on spack, see the 
[Spack documentation site](https://spack.readthedocs.io/en/latest/).

Now, look in /opt/ohpc/pub/examples:
```
headnode] root$ ls /opt/ohpc/pub/examples
```

You'll see a variety of LAMMPS example jobs to run. 
For most of them, we can run a job with the following script:
(no need to reproduce the comments)

```
#!/bin/bash
#SBATCH -N 2
#SBATCH -n 12
#SBATCH -o lammps_%A.out #%A is shorthand for the jobID

module load gnu
module load openmpi
module load lammps

mkdir -p /export/workdir_${SLURM_JOB_ID}/
cp -r /opt/ohpc/pub/examples/micelles /export/workdir_${SLURM_JOB_ID}/

cd /export/workdir_${SLURM_JOB_ID}/ 
mpirun -np 12 lmps < in.micelles > lmps_run.txt
```

<!---
## TODO: Add some interesting jobs. With Software. Also, add some software.
## Build some software! Use the OpenHPC Modules, or OHPC-Spack?
## Actually, shouldn't I use Singularity instead?
## And maybe X-forwarding. NO! can you imagine the chaos?
## This should happen Before Elasticity? Probably. Keep interest up.

##SPack 
 - FIRST: module load gnu/, THEN spack compiler find!
 - don't forget `spack compiler find'
 - remember to edit $spack/etc/defaults/config.yaml
 - add core_compilers to lmod section! - use spack compiler list...
 - THEN, add module file to the compiler section!
 - is this really worth it?
-->


# Add Elasticity

While the work we've done so far is plenty for a simple cluster,
it's also a great way to burn through your Jetstream allocation 
if you have any kind of significant workload (and use larger 
instances). Luckily, we can
leverage Slurm's native cloud compatibility to create a interface
with Openstack to keep our compute instances alive only when we
need them. Slurm will handle the details of deciding when
to bring nodes up and down, as long as we instruct it *how* to do so.

First of all, give slurm access to Openstack:
Place a copy of your openrc.sh in /etc/slurm/, and make sure it's owned,
and only readable by the 'slurm' user:
```
headnode] root$ cp openrc.sh /etc/slurm/
headnode] root$ chown slurm:slurm /etc/slurm/openrc.sh
headnode] root$ chmod 400 /etc/slurm/openrc.sh
```
We'll also create a log file for slurm to use:
```
touch /var/log/slurm_elastic.log
chown slurm:slurm /var/log/slurm_elastic.log
```

Now, let's create scripts that slurm can run to suspend and resume the nodes.
For node resume, edit
```
headnode] root$ vim /usr/local/sbin/slurm_resume.sh
...
#!/bin/bash
source /etc/slurm/openrc.sh


echo "Node resume invoked: $0 $*" >> $log_loc


for host in $(scontrol show hostname $1)
do
  if [[ "$(openstack server show $host 2>&1)" =~ "No server with a name or ID of" ]]; then 
    echo "$host does not exist - please create first!" >> $log_loc 
    exit 1
  else
    $node_status=$(openstack server start $host)
    echo "$host status is: $node_status" >> $log_loc
  fi
done

for host in $(scontrol show hostname $1)
do
  until [[ $node_status == "ACTIVE" ]]; do
    sleep 3
    node_status=$(openstack server show $host | awk '/status/ {print $4}')
    echo "$host status is: $node_status" >> $log_loc
  done
done

```

For node stopping, create a script in /usr/local/sbin/slurm_suspend.sh:
```
#!/bin/bash

source /etc/slurm/openrc.sh

log_loc=/var/log/slurm_elastic.log

echo "Node suspend invoked: $0 $*" >> $log_loc 

hostlist=$(openstack server list)

for host in $(scontrol show hostname $1)
do
  if [[ "$(echo "$hostlist" | awk -v host=$host '$0 ~ host {print $6}')" == "ACTIVE" ]]; then 
    echo "Stopping $host" >> $log_loc
    openstack server stop $host
  else
    echo "$host not ACTIVE" >> $log_loc
    exit 1
  fi
done

```
Make sure slurm_resume.sh and slurm_suspend.sh are owned and executable by the
slurm user!
```
headnode] root$ chown slurm:slurm /usr/local/sbin/slurm_resume.sh
headnode] root$ chmod u+x /usr/local/sbin/slurm_resume.sh
```

We'll need to update the slurm.conf, by adding the following lines:
```
headnode] root$ vim /etc/slurm/slurm.conf
#CLOUD CONFIGURATION
PrivateData=cloud
ResumeProgram=/usr/local/sbin/slurm_resume.sh
SuspendProgram=/usr/local/sbin/slurm_suspend.sh
ResumeRate=0 #number of nodes per minute that can be created; 0 means no limit
ResumeTimeout=300 #max time in seconds between ResumeProgram running and when the node is ready for use
SuspendRate=0 #number of nodes per minute that can be suspended/destroyed
SuspendTime=30 #time in seconds before an idle node is suspended
SuspendTimeout=30 #time between running SuspendProgram and the node being completely down
```

Be sure to copy this new slurm.conf out to your compute nodes, and restart!
```
headnode] root$ scp /etc/slurm/slurm.conf ${OS_USERNAME}-compute-0:/etc/slurm/slurm.conf
headnode] root$ ssh ${OS_USERNAME}-compute-0 'systemctl restart slurmd'
```

At this point, your compute nodes should be managed by slurm! 

While they're currently in 'idle' state, that won't last for longer than
SuspendTime. Wait for 30 seconds, and submit a job.
Watch the logs in /var/log/slurm_elastic.log.
