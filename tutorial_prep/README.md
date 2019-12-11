# Openstack Cluster Tutorial: Infrastructure Preparation

This directory contains the necessary scripts to create a set of virtual machines
on Openstack, provided you have a set of accounts available, in a file named 
"accounts.txt", space delimited, with columns like:

```$human_friendly_name    $OS_USERNAME     $OS_PASSWORD```

---
The `infra_create.sh` script will create three nodes per user, with names like
```
$human_friendly_name-headnode
$human_friendly_name-compute-0
$human_friendly_name-compute-1
```

The instances are placed in 'shelved' state, to conserve resources prior to actually
running a workshop. It's best to create the infrastructure at least a day beforehand, to
allow time for testing that everything works as expected. (This is a TODO, to create a test
script...)

By default, this assumes that the login user on the VMs is `centos`. A search and replace
for 'centos@' may be necessary if your cloud behaves differently. This **also** assumes that
the $human_friendly_name is in the format "train??" where ?? are digits. Only a couple of regexes
must be changed if yours have a different convention.

SSH keys will be created for the centos user on each headnode, and shared between centos
and the root user on the compute instances. These scripts do NOT do any other setup of
the cluster, since that is the purpose of this workshop - after several iterations, we
have found that setting up ssh keys is often a stumbling block, and wastes a significant 
amount of time that would be best spent elsewhere.

There will be a `user_list.csv` file created, which contains the necessary info for users
to access their VMs:
```
$human_friendly_name $list_of_instances_with_IP_address $login_password
```
This is intended to provide you with an easily printed file, which you can slice up and
provide to users via pre-printed slips during the actual workshop.

They'll login to the headnode via ssh, as the centos user. The compute instances are NOT 
accessible via a public IP address.

---
The `DestroyAccounts.sh` should remove **everything** that `infra_create.sh` builds for you - so
run carefully after your workshop or tutorial is over. This also contains reference to the 
"train??" convention, and will need editing if your usernames are different!

---
The `infra_resume.sh` unshelves all of the instances on your Openstack project for use during
the actual tutorial.

---
The `os_create.sh` is used by `infra_create.sh` to contain all of the details of how the instances
are created - if you're curious how we're using the openstack CLI here, feel free to dig in!

---
The `os_shelve.sh` script will shelve all of the instances on your project, if you'd like to pause
the workshop or run over multiple days, while preserving resources during the interim.

---
The `os_fix_logins.sh` script is optional, and contains only the parts of `os_create.sh` pertaining
to setting the local passwords on the instances, in case the openstack build works, but for some
reason the user setup fails. Hopefully you will not need this!
