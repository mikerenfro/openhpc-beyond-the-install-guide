#!/bin/bash
set -e

echo "=== create.sh"

tofu apply -auto-approve

echo "--- removing known-hosts entries"

OHPC_IP4=$(tofu output -json ohpc-btig-sms-ipv4 | jq -r '.[]')
if [[ -n "${OHPC_IP4}" ]] ; then
  for IP in ${OHPC_IP4}; do
    ssh-keygen -R $IP
  done
fi

./macs_to_host_vars.sh

echo "=== create.sh $(echo ${OHPC_IP4})"

for ip in ${OHPC_IP4}; do
  while ! ssh-keyscan ${ip} >& /dev/null; do
    waiting on ${ip} to take an ssh connection
    sleep 5
  done
done
echo "--- done."