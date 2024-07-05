#!/bin/bash

echo "=== delete.sh"

get_cluster_ips_counts  # sets OHPC_IP4, CLUSTER_NUMBERS, CLUSTER_COUNT
remove_old_keys  # removes any known_hosts entries for each of ${OHPC_IP4}

tofu destroy -auto-approve
