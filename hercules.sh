#!/bin/bash

ccache=$(grep -F 'default_ccache_name' /etc/krb5.conf | grep -v '#' | cut -d'=' -f2 | xargs)
ccache_type=$(echo $ccache | cut -d':' -f1)

if [[ ${ccache} == "" ]]; then
echo "Look for /tmp/krb5cc_$(id -u)"
exit 1
fi
if [[ ${ccache_type} == "DIR" ]]; then
location=$(echo ${ccache} | cut -d':' -f2)
echo "Look in ${location}"
exit 2
fi
if [[ ${ccache_type} == "MEMORY" ]]; then
echo "You're gonna have to do some memory analysis..."
exit 3
fi
if [[ ${ccache_type} == "KEYRING" ]]; then
keyring_type=$(echo ${ccache} | cut -d':' -f2)
fi

keyring_name=$(echo ${ccache} | cut -d':' -f3)
# Handle named keyring
if [[ "$keyring_name" == "" ]]; then
keyring_name="$keyring_type"
fi

# Persistent keyring is approached differently
if [[ "${keyring_type}" == "persistent" ]]; then
# Attach persistent for UID to our session keyring
keyctl get_persistent @s "$(id -u)" > /dev/null
keyring=$(keyctl search @s keyring "$(id -u)")
else
# Get named keyring
keyring=$(keyctl search @s "keyring" "${keyring_name}")
# Check £? here: no keyring (no credentials found in keyring)
fi

key_components=( $(keyctl rlist ${keyring}) )

tmp_dir=$(mktemp -d)
for i in ${!key_components[@]}; do
SPN="$(keyctl rdescribe ${key_components[${i}]} | rev | cut -d';' -f1 | rev)"
# We don't care about the configuration entries
if [[ ! "${SPN}" =~ "X-CACHECONF" ]]; then
# / is illegal in a filename
safe_name=$(echo ${SPN} | tr '/' '_')
keyctl pipe "${key_components[${i}]}" > "${tmp_dir}/${safe_name}.bin"
fi
done
