#!/bin/bash

if [ ! -f user-passwords.txt ]; then
    echo "ERROR: see $0 for instructions on generating the user passwords."
    exit 1
fi
# Generate students' plain-text passwords from https://beta.xkpasswd.net ,
# store them in user-passwords.txt , then convert them into salted hashes
# for ansible host_vars files, one file per student. Make sure there's an
# empty blank line at the end (i.e., "wc -l user-passwords.txt" should equal
# the number of students in the class).
i=0
while read p ; do
    host_var_file=ansible/host_vars/sms-${i}
    if [ -f ${host_var_file} ]; then
        pc=$(python -c "import crypt,getpass; print(crypt.crypt('$p', crypt.mksalt(crypt.METHOD_SHA512)))")
        echo "user1_password: $pc" >> ${host_var_file}
        echo "user2_password: $pc" >> ${host_var_file}
        ((i++))
    else
        break
    fi
done < user-passwords.txt