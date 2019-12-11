#!/bin/bash

if [[ -z "$1" ]]; then
  echo "NO USER NAME GIVEN! Please re-run with ./os_create.sh <user-name>"
  exit
fi
username=$1

if [[ ! -e ./openrc-${username}.sh ]]; then
  echo "NO OPENRC FOUND! CREATE ONE, AND TRY AGAIN!"
  exit
fi

#if [[ -z "$2" ]]; then
#  echo "NO SERVER NAME GIVEN! Please re-run with ./headnode_create.sh <server-name>"
#  exit
#fi

if [[ ! -e ${HOME}/.ssh/id_rsa.pub ]]; then
#This may be temporary... but seems fairly reasonable.
  echo "NO KEY FOUND IN ${HOME}/.ssh/id_rsa.pub! - please create one and re-run!"  
  exit
fi

source ./openrc-${username}.sh

# Defining a function here to check for quotas, and exit if this script will cause problems!
# also, storing 'quotas' in a global var, so we're not calling it every single time
quotas=$(openstack quota show)
quota_check () 
{
quota_name=$1
type_name=$2 #the name for a quota and the name for the thing itself are not the same
number_created=$3 #number of the thing that we'll create here.

current_num=$(openstack ${type_name} list -f value | wc -l)

max_types=$(echo "${quotas}" | awk -v quota=${quota_name} '$0 ~ quota {print $4}')

#echo "checking quota for ${quota_name} of ${type_name} to create ${number_created} - want ${current_num} to be less than ${max_types}"

if [[ "${current_num}" -lt "$((max_types + number_created))" ]]; then 
  return 0
fi
return 1
}


quota_check "networks" "network" 1
quota_check "subnets" "subnet" 1
quota_check "routers" "router" 1
quota_check "key-pairs" "keypair" 1
quota_check "instances" "server" 1

# Ensure that the correct private network/router/subnet exists
if [[ -z "$(openstack network list | grep ${OS_USERNAME}-elastic-net)" ]]; then
  openstack network create ${OS_USERNAME}-elastic-net
  openstack subnet create --network ${OS_USERNAME}-elastic-net --subnet-range 10.0.0.0/24 ${OS_USERNAME}-elastic-subnet1
fi
##openstack subnet list
if [[ -z "$(openstack router list | grep ${OS_USERNAME}-elastic-router)" ]]; then
  openstack router create ${OS_USERNAME}-elastic-router
  openstack router add subnet ${OS_USERNAME}-elastic-router ${OS_USERNAME}-elastic-subnet1
  openstack router set --external-gateway public ${OS_USERNAME}-elastic-router
fi
#openstack router show ${OS_USERNAME}-api-router

security_groups=$(openstack security group list -f value)
if [[ ! ("${security_groups}" =~ "${OS_USERNAME}-cluster") ]]; then
  openstack security group create --description "group for ${username} cluster" ${OS_USERNAME}-cluster
  openstack security group rule create --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0 ${OS_USERNAME}-cluster
  openstack security group rule create --protocol tcp --dst-port 1:65535 --remote-ip 10.0.0.0/0 ${OS_USERNAME}-cluster
  openstack security group rule create --protocol icmp ${OS_USERNAME}-cluster
fi

#Check if ${HOME}/.ssh/id_rsa.pub exists in JS
if [[ -e ${HOME}/.ssh/id_rsa.pub ]]; then
  home_key_fingerprint=$(ssh-keygen -l -E md5 -f ${HOME}/.ssh/id_rsa.pub | sed  's/.*MD5:\(\S*\) .*/\1/')
fi
openstack_keys=$(openstack keypair list -f value)

home_key_in_OS=$(echo "${openstack_keys}" | awk -v mykey=${home_key_fingerprint} '$2 ~ mykey {print $1}')

if [[ -n "${home_key_in_OS}" ]]; then
  OS_keyname=${home_key_in_OS}
elif [[ -n $(echo "${openstack_keys}" | grep ${OS_USERNAME}-elastic-key) ]]; then
  openstack keypair delete ${OS_USERNAME}-elastic-key
# This doesn't need to depend on the OS_PROJECT_NAME, as the slurm-key does, in install.sh and slurm_resume
  openstack keypair create --public-key ${HOME}/.ssh/id_rsa.pub ${OS_USERNAME}-elastic-key
  OS_keyname=${OS_USERNAME}-elastic-key
else
# This doesn't need to depend on the OS_PROJECT_NAME, as the slurm-key does, in install.sh and slurm_resume
  openstack keypair create --public-key ${HOME}/.ssh/id_rsa.pub ${OS_USERNAME}-elastic-key
  OS_keyname=${OS_USERNAME}-elastic-key
fi

servername=${username}-headnode

image_name=$(openstack image list -f value | grep -iE "API-Featured-centos7-[[:alpha:]]{3,4}-[0-9]{2}-[0-9]{4}" | cut -f 2 -d' ')

echo "openstack server create --user-data prevent-updates.ci --flavor m1.small --image ${image_name} --key-name ${OS_keyname} --security-group ${OS_USERNAME}-cluster --nic net-id=${OS_USERNAME}-elastic-net ${servername}"
openstack server create --user-data prevent-updates.ci --flavor m1.small --image ${image_name} --key-name ${OS_keyname} --security-group ${OS_USERNAME}-cluster --nic net-id=${OS_USERNAME}-elastic-net ${servername}

public_ip=$(openstack floating ip create public | awk '/floating_ip_address/ {print $4}')
#For some reason there's a time issue here - adding a sleep command to allow network to become ready
sleep 10
openstack server add floating ip ${servername} ${public_ip}

ssh_opts="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

hostname_test=$(ssh ${ssh_opts} centos@${public_ip} 'hostname')
echo "test1: ${hostname_test}"
until [[ ${hostname_test} =~ "$2" ]]; do
  sleep 2
  hostname_test=$(ssh ${ssh_opts} centos@${public_ip} 'hostname')
  echo "ssh ${ssh_opts} centos@${public_ip} 'hostname'"
  echo "test2: ${hostname_test}"
done


#openstack server create --user-data prevent-updates.ci --flavor m1.small --image ${image_name} --key-name ${OS_keyname} --security-group ${OS_USERNAME}-cluster --nic net-id=${OS_USERNAME}-elastic-net ${username}-compute-0
#openstack server create --user-data prevent-updates.ci --flavor m1.small --image ${image_name} --key-name ${OS_keyname} --security-group ${OS_USERNAME}-cluster --nic net-id=${OS_USERNAME}-elastic-net ${username}-compute-1


scp ${ssh_opts} ./openrc-${username}.sh prevent-updates.ci centos@${public_ip}:
ssh ${ssh_opts} centos@${public_ip} 'echo -e "MATCH user centos\n  PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config >/dev/null && sudo systemctl reload sshd'
ssh ${ssh_opts} centos@${public_ip} 'echo "centos":"${OS_PASSWORD}" | sudo chpasswd' 
ssh ${ssh_opts} centos@${public_ip} 'ssh-keygen -q -f .ssh/id_rsa -P "" -t rsa -b 2048'
ssh ${ssh_opts} centos@${public_ip} 'sudo yum -y install centos-release-openstack-rocky https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm'
ssh ${ssh_opts} centos@${public_ip} 'sudo yum -y install python2-openstackclient'
ssh ${ssh_opts} centos@${public_ip} 'sudo yum -y update'
ssh ${ssh_opts} centos@${public_ip} "source ./openrc-${username}.sh && \
	openstack keypair create --public-key /home/centos/.ssh/id_rsa.pub ${OS_keyname}-auto && \
	openstack server create --user-data prevent-updates.ci --flavor m1.quad --image ${image_name} --key-name ${OS_keyname}-auto --security-group ${OS_USERNAME}-cluster --nic net-id=${OS_USERNAME}-elastic-net ${username}-compute-0
	openstack server create --user-data prevent-updates.ci --flavor m1.quad --image ${image_name} --key-name ${OS_keyname}-auto --security-group ${OS_USERNAME}-cluster --nic net-id=${OS_USERNAME}-elastic-net ${username}-compute-1"

echo "You should be able to login to your server with your Jetstream key: ${OS_keyname}, at ${public_ip}"
