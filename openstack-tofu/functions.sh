function remove_old_keys() {
  if [[ -n "${OHPC_IP4}" ]] ; then
    if [ -f ~/.ssh/known_hosts ]; then
      echo "--- removing known-hosts entries"
      for IP in ${OHPC_IP4}; do
        ssh-keygen -R $IP
      done
    fi
  fi
}

function populate_host_vars() {
  echo "Populating host_vars for clusters: $(echo ${CLUSTER_NUMBERS})"
  for n in $CLUSTER_NUMBERS; do
      host_var_file=${REPO_FOLDER}/ansible/host_vars/hpc${n}-sms
      echo ${host_var_file}
      mkdir -p ${REPO_FOLDER}/ansible/host_vars
      echo > ${host_var_file}
      num_computes=$(tofu output -json node-macs | jq "keys[] as \$k | \$k | select(match(\"hpc${n}-\"))" | wc -l)
      if [ ${num_computes} -gt 0 ]; then
        echo "compute_nodes:" >> ${host_var_file}
        i=1
        for j in $(tofu output -json node-macs | jq "keys[] as \$k | \$k | select(match(\"hpc${n}-\"))"); do
            mac=$(tofu output -json node-macs | jq -r ".[$j][0]")
            echo "- { name: \"c${i}\", mac: \"${mac}\" }" >> ${host_var_file}
            ((i++))
        done
      fi
      echo "num_computes: ${num_computes}" >> ${host_var_file}
        echo "gpu_nodes:" >> ${host_var_file}
    i=1
    for j in $(tofu output -json gpunode-macs | jq "keys[] as \$k | \$k | select(match(\"hpc${n}-\"))"); do
        mac=$(tofu output -json gpunode-macs | jq -r ".[$j][0]")
        echo "- { name: \"g${i}\", mac: \"${mac}\" }" >> ${host_var_file}
        ((i++))
    done
    num_gpus=$(tofu output -json gpunode-macs | jq "keys[] as \$k | \$k | select(match(\"hpc${n}-\"))" | wc -l)
    echo "num_gpus: ${num_gpus}" >> ${host_var_file}
    login_mac=$(tofu output -json login-macs | jq -r ".[\"${n}\"][0]")
    echo "login_mac: \"${login_mac}\"" >> ${host_var_file}
    sms_ipv4=$(tofu output -json sms-ipv4 | jq -r ".[${n}]")
    echo "sms_ipv4: ${sms_ipv4}" >> ${host_var_file}
    login_ipv4=$(tofu output -json login-ipv4 | jq -r ".[${n}]")
    echo "login_ipv4: ${login_ipv4}" >> ${host_var_file}
  done

  if [ ! -f ${REPO_FOLDER}/ansible/user-passwords.txt ]; then
    xkcdpass \
      --count=${CLUSTER_COUNT} \
      --delimiter=. \
      --max=8 \
      --min=3 \
      --valid-chars='[a-z]' > ${REPO_FOLDER}/ansible/user-passwords.txt
  else
    if [ $(cat ${REPO_FOLDER}/ansible/user-passwords.txt | wc -w) -lt ${CLUSTER_COUNT} ]; then
      echo "${REPO_FOLDER}/ansible/user-passwords.txt contains too few passwords for this class size."
      echo "Exiting".
      exit 1
    else
      echo "${REPO_FOLDER}/ansible/user-passwords.txt already exists, not overwriting"
    fi
  fi
  i=0
  echo "populating user_creds into host_vars files"
  set +e
  while read p ; do
      host_var_file=${REPO_FOLDER}/ansible/host_vars/hpc${i}-sms
      if [ -f ${host_var_file} ]; then
          pc=$(python -c "import crypt; print(crypt.crypt('$p', crypt.mksalt(crypt.METHOD_SHA512)))")
          # https://unix.stackexchange.com/a/158402
          echo "user_creds:" >> ${host_var_file}
          for n in $(seq 1 ${USERS_PER_HOST}); do
              echo "- { username: 'user${n}', password: '$pc' }" >> ${host_var_file}
          done
          ((i++))
      else
          break
      fi
  done < ${REPO_FOLDER}/ansible/user-passwords.txt
  set -e
}

function wait_for_sms_boot() {
  for ip in ${OHPC_IP4}; do
    set +e
    echo -ne "waiting on ${ip} to take an ssh connection."
    while ! ssh-keyscan ${ip} >& /dev/null; do
      echo -ne "."
      sleep 5
    done
    echo ""
    set -e
  done
}

function get_cluster_ips_counts() {
  OHPC_IP4=$(tofu output -json sms-ipv4 | jq -r '.[]')
  CLUSTER_NUMBERS=$(tofu output -json sms-names | jq -r 'keys[] as $k | "\($k)"' | sort -n | uniq)
  CLUSTER_COUNT=$(echo ${CLUSTER_NUMBERS} | wc -w)
}