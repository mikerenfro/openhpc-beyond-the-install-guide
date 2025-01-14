#!/bin/bash
set -e

REPO_FOLDER=/vagrant
source ${REPO_FOLDER}/openstack-tofu/functions.sh

echo "=== create.sh"

tofu apply -auto-approve  # creates routers, networks, subnets, rules, instances, ansible inventory, local ssh config for each SMS
get_cluster_ips_counts  # sets OHPC_IP4, CLUSTER_NUMBERS, CLUSTER_COUNT
remove_old_keys  # removes any known_hosts entries for each of ${OHPC_IP4}
USERS_PER_HOST=2
populate_host_vars  # grabs MAC addresses for each cluster's nodes and passwords for each test user account, dumps them into host_vars files for each SMS
echo "OHPC_IP4 for SMS is $(echo ${OHPC_IP4}), now waiting for all instances to boot"
wait_for_sms_boot  # waits for all SMS instances to be available over ssh before continuing
echo "Hopefully instances have all booted now"

echo "=== create.sh $(echo ${OHPC_IP4})"
echo "Making student handout .docx files:"
(cd ${REPO_FOLDER} && for c in ${CLUSTER_NUMBERS}; do python3.12 make-student-handouts.py ${c}; done)
echo "--- done."
