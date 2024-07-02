#!/bin/bash

cluster_numbers=$(tofu output -json ohpc-btig-macs | jq -r 'keys[] as $k | "\($k)"' | cut -d- -f1 | sort | uniq | sed 's/cluster//g')
for n in $cluster_numbers; do
    host_var_file=ansible/host_vars/sms-${n}
    echo ${host_var_file}
    echo "compute_nodes:" > ${host_var_file}
    i=1
    for n in $(tofu output -json ohpc-btig-macs | jq "keys[] as \$k | \$k | select(match(\"cluster${n}\"))"); do
        mac=$(tofu output -json ohpc-btig-macs | jq -r ".[$n][0]")
        echo "- { name: \"c${i}\", mac: \"${mac}\" }" >> ${host_var_file}
        ((i++))
    done
done
