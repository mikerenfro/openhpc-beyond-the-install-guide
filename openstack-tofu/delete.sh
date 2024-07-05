#!/bin/bash

echo "=== delete.sh"

echo "--- removing known-hosts entries"

OHPC_IP4=$(tofu output -json ohpc-btig-sms-ipv4 | jq -r '.[]')
if [[ -n "${OHPC_IP4}" ]] ; then
  for IP in ${OHPC_IP4}; do
    ssh-keygen -R $IP
  done
fi

tofu destroy -auto-approve
