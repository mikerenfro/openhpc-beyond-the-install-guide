#!/bin/bash

if [ ! -f user-passwords.txt ]; then
    echo "ERROR: see $0 for instructions on generating the user passwords."
    exit 1
fi
users_per_host=2
# Generate students' plain-text passwords from xkcdpass, store them in
# user-passwords.txt , then convert them into salted hashes for ansible
# host_vars files, one file per student.
i=0
while read p ; do
    host_var_file=ansible/host_vars/sms-${i}
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
done < user-passwords.txt