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

echo "=== create.sh $(echo ${OHPC_IP4})"
