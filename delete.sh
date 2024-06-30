#!/bin/bash

echo "=== delete.sh"

echo "--- removing known-hosts entries"

OHPC_IP4=$(tofu output -raw ohpc-btig-sms-ipv4)
if [[ -n "${OHPC_IP4}" ]] ; then
  ssh-keygen -R $OHPC_IP4
fi

tofu destroy -auto-approve
