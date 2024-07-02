#!/bin/bash

cluster_numbers=$(tofu output -json ohpc-btig-macs | jq -r 'keys[] as $k | "\($k)"' | cut -d- -f1 | sort | uniq | sed 's/cluster//g')
for n in $cluster_numbers; do
    host_var_file=ansible/host_vars/sms-${n}
    echo "macs:" > ${host_var_file}
    for n in $(tofu output -json ohpc-btig-macs | jq "keys[] as \$k | \$k | select(match(\"cluster${n}\"))"); do
        macs=$(tofu output -json ohpc-btig-macs | jq -r ".[$n][0]")
        for mac in $macs; do
            echo "- ${mac}" >> ${host_var_file}
        done
    done
done
