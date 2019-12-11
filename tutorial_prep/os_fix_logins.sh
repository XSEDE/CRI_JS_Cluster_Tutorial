#!/bin/bash

echo "THIS SCRIPT INTENDED FOR REPAIR PURPOSES ONLY, AFTER RUNNING infra_create.sh. 
This *should* create working logins and shared ssh keys across the headnode and compute 
instances if the initial creation was successful, but login setup failed for some reason 
(typically some kind of timeout or temporary network issue). Uncomment the next line if 
you are *sure* you want to run this!"
exit
#feel free to comment out the giant warning blob as well!

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

headnode_name=${username}-headnode

public_ip=$(openstack server list -f value -c Networks --name ${headnode_name} | sed 's/.*, //')

ssh_opts="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

openstack server unshelve ${headnode_name}

hostname_test=$(ssh ${ssh_opts} centos@${public_ip} 'hostname')
echo "test1: ${hostname_test}"
until [[ ${hostname_test} =~ "$2" ]]; do
  sleep 2
  hostname_test=$(ssh ${ssh_opts} centos@${public_ip} 'hostname')
  echo "ssh ${ssh_opts} centos@${public_ip} 'hostname'"
  echo "test2: ${hostname_test}"
done

OS_keyname=${OS_USERNAME}-elastic-key
image_name=$(openstack image list -f value | grep -iE "API-Featured-centos7-[[:alpha:]]{3,4}-[0-9]{2}-[0-9]{4}" | cut -f 2 -d' ')

scp ${ssh_opts} ./openrc-${username}.sh prevent-updates.ci centos@${public_ip}:
ssh ${ssh_opts} centos@${public_ip} 'echo -e "\nMATCH user centos\n  PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config >/dev/null && sudo systemctl reload sshd'
ssh ${ssh_opts} centos@${public_ip} "echo -e \"centos:${OS_PASSWORD}\" | sudo chpasswd"
ssh ${ssh_opts} centos@${public_ip} 'ssh-keygen -q -f .ssh/id_rsa -P "" -t rsa -b 2048'
ssh ${ssh_opts} centos@${public_ip} 'sudo yum -y install centos-release-openstack-rocky https://github.com/openhpc/ohpc/releases/download/v1.3.GA/ohpc-release-1.3-1.el7.x86_64.rpm'
ssh ${ssh_opts} centos@${public_ip} 'sudo yum -y install python2-openstackclient vim net-tools'
ssh ${ssh_opts} centos@${public_ip} 'sudo yum -y update'
ssh ${ssh_opts} centos@${public_ip} "source ./openrc-${username}.sh && \
	openstack keypair create --public-key /home/centos/.ssh/id_rsa.pub ${OS_keyname}-auto"

openstack server create --user-data prevent-updates.ci --flavor m1.small --image ${image_name} --key-name ${OS_keyname}-auto --security-group ${OS_USERNAME}-cluster --nic net-id=${OS_USERNAME}-elastic-net ${username}-compute-0
openstack server create --user-data prevent-updates.ci --flavor m1.small --image ${image_name} --key-name ${OS_keyname}-auto --security-group ${OS_USERNAME}-cluster --nic net-id=${OS_USERNAME}-elastic-net ${username}-compute-1

hostname_test=$(ssh ${ssh_opts} centos@${public_ip} 'hostname')
echo "test1: ${hostname_test}"
until [[ ${hostname_test} =~ "$2" ]]; do
  sleep 2
  hostname_test=$(ssh ${ssh_opts} centos@${public_ip} 'hostname')
  echo "ssh ${ssh_opts} centos@${public_ip} 'hostname'"
  echo "test2: ${hostname_test}"
done
echo "You should be able to login to your server with your Jetstream key: ${OS_keyname}, at ${public_ip}"
