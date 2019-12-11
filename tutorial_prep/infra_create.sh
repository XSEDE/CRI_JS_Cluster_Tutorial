#!/bin/bash

for user in $(awk '/train/ {print $1'} accounts.txt) 
do 
  awk -v user="${user}" '$0 ~ user {print "export OS_PROJECT_DOMAIN_NAME=tacc \nexport OS_USER_DOMAIN_NAME=tacc \nexport OS_PROJECT_NAME=TG-CDA170005 \nexport OS_USERNAME="$2"\nexport OS_PASSWORD='\''" $3 "'\'' \nexport OS_AUTH_URL=https://iu.jetstream-cloud.org:35357/v3 \nexport OS_IDENTITY_API_VERSION=3" }' tg_passwords.txt > openrc-${user}.sh

# testing purposes:
#  source openrc-${user}.sh
#  openstack image list | grep API | grep -i centos | grep 7

#create headnode and computes
  ./os_create.sh ${user}

#generate csv for printing pw slips
  source openrc-${user}.sh
  server_list=$(openstack server list -f value -c Name -c Networks | grep ${user} | sed 's/\(.*\)train.*=\(.*\)/\1 \2/' | tr ',' ' ' |tr '\n' ','| sed 's/,$//')
  echo "${user}, ${server_list}, ${OS_PASSWORD}" >> user_info.csv

#shelve infra
  ./os_shelve.sh ${user}
done
