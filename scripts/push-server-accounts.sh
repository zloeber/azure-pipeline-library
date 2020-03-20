#!/bin/bash
# Simple script to create a new key in your $home/.ssh folder for an account
# and server IP then drop it to the remote user's authorized_keys file.
# Requires: 
#  - Password authentiation enabled
#  - root account access already enabled for another account (like azureuser)
#
# ./push-server-account.sh azureuser user1 10.0.0.1 ~/.ssh

rootuser=${1?"Usage: $0 azureuser user1 10.0.0.1 ~/.ssh"}
account=${2?"Usage: $0 user1 10.0.0.1 ~/.ssh"}
ip=${3?"Usage: $0 user1 10.0.0.1 ~/.ssh"}
keypath=${4?"Usage: $0 user1 10.0.0.1 ~/.ssh"}

# This should be done as your normal account
mkdir -p ${keypath}
touch ${keypath}/config

# This gets added to your local config file
cat >> ${keypath}/config <<-END-OF-STANZA
Host ${ip}
  User ${account}
  IdentityFile ${keypath}/${account}_id_rsa
END-OF-STANZA

ssh-keygen -t rsa -N "" -f "${keypath}/${account}_id_rsa" -C ${account}
chmod 600 ${keypath}/${account}*
ssh ${rootuser}@${ip} "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# You will be prompted for the ${account} password next.
cat ~/.ssh/${account}_id_rsa.pub | ssh ${account}@${ip} "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# This gets added to your local config file
cat >> ${keypath}/config <<-END-OF-STANZA
Host ${ip}
  User ${account}
  IdentityFile ~/.ssh/${account}_id_rsa
END-OF-STANZA

echo "ssh config: ${keypath}/config"
echo "ssh keys: ${account}_id_rsa*"
echo "To access:"
echo "  ssh -F ${keypath}/config ${account}@${ip}"