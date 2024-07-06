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
      host_var_file=${REPO_FOLDER}/ansible/host_vars/sms-${i}
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
  OHPC_IP4=$(tofu output -json ohpc-btig-sms-ipv4 | jq -r '.[]')
  CLUSTER_NUMBERS=$(tofu output -json ohpc-btig-macs | jq -r 'keys[] as $k | "\($k)"' | cut -d- -f1 | sort | uniq | sed 's/cluster//g' | sort -n)
  CLUSTER_COUNT=$(echo ${CLUSTER_NUMBERS} | wc -w)
}