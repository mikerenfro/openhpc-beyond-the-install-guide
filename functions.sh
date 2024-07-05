function remove_old_keys() {
  if [[ -n "${OHPC_IP4}" ]] ; then
    echo "--- removing known-hosts entries"
    for IP in ${OHPC_IP4}; do
      ssh-keygen -R $IP
    done
  fi
}

function populate_host_vars() {
  for n in $CLUSTER_NUMBERS; do
      host_var_file=${REPO_FOLDER}/ansible/host_vars/sms-${n}
      echo ${host_var_file}
      echo "compute_nodes:" > ${host_var_file}
      i=1
      for j in $(tofu output -json ohpc-btig-macs | jq "keys[] as \$k | \$k | select(match(\"cluster${n}-\"))"); do
          mac=$(tofu output -json ohpc-btig-macs | jq -r ".[$j][0]")
          echo "- { name: \"c${i}\", mac: \"${mac}\" }" >> ${host_var_file}
          ((i++))
      done
      num_computes=$(tofu output -json ohpc-btig-macs | jq "keys[] as \$k | \$k | select(match(\"cluster${n}-\"))" | wc -l)
      echo "num_computes: ${num_computes}" >> ${host_var_file}
  done

  if [ ! -f ${REPO_FOLDER}/user-passwords.txt ]; then
    xkcdpass \
      --count=${CLUSTER_COUNT} \
      --delimiter=. \
      --max=8 \
      --min=3 \
      --valid-chars='[a-z]' > ${REPO_FOLDER}/user-passwords.txt
  else
    if [ $(wc -l ${REPO_FOLDER}/user-passwords.txt) -lt ${CLUSTER_COUNT} ]; then
      echo "/vagrant/user-passwords.txt contains too few passwords for this class size."
      echo "Exiting".
      exit 1
    else
      echo "${REPO_FOLDER}/user-passwords.txt already exists, not overwriting"
    fi
  fi
  i=0
  while read p ; do
      host_var_file=${REPO_FOLDER}/ansible/host_vars/sms-${i}
      if [ -f ${host_var_file} ]; then
          pc=$(python -c "import crypt; print(crypt.crypt('$p', crypt.mksalt(crypt.METHOD_SHA512)))")
          # https://unix.stackexchange.com/a/158402
          echo "user_creds:" >> ${host_var_file}
          for n in $(seq 1 ${users_per_host}); do
              echo "- { username: 'user${n}', password: '$pc' }" >> ${host_var_file}
          done
          ((i++))
      else
          break
      fi
  done < ${REPO_FOLDER}/user-passwords.txt
}

function wait_for_sms_boot() {
  for ip in ${OHPC_IP4}; do
    while ! ssh-keyscan ${ip} >& /dev/null; do
      echo waiting on ${ip} to take an ssh connection
      sleep 5
    done
  done
}

function get_cluster_ips_counts() {
  OHPC_IP4=$(tofu output -json ohpc-btig-sms-ipv4 | jq -r '.[]')
  CLUSTER_NUMBERS=$(tofu output -json ohpc-btig-macs | jq -r 'keys[] as $k | "\($k)"' | cut -d- -f1 | sort | uniq | sed 's/cluster//g' | sort -n)
  CLUSTER_COUNT=$(echo ${CLUSTER_NUMBERS} | wc -w)
}