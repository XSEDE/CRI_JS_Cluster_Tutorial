#!/bin/bash

for user in $(awk '/train/ {print $1'} accounts.txt) 
do 
  source openrc-${user}.sh
  server_list=$(openstack server list -f value -c Name | grep ${user} | tr '\n' ' ')
  for server in ${server_list}
  do
    openstack server unshelve ${server}
    sleep 2
  done
done
