#!/bin/bash

user=$1

source openrc-${user}.sh
server_list=$(openstack server list -f value -c Name | grep ${user} | tr '\n' ' ')
for server in ${server_list}
do
  openstack server shelve ${server}
done
