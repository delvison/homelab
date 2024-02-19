#!/usr/bin/env bash

set -e

age_key_file="${HOME}/.config/sops/age/homelab-keys.txt.age"

if [ -f "${age_key_file}" ]; then 
  echo "[i] Please insert homelab-key password:"
  [ -z "${SOPS_AGE_KEY}" ] && age_key=$(age -d ${age_key_file})

  for i in $(find . -name "*.enc"); do 
    real_name=$(echo $i | sed 's/\.enc$//g'); 
    echo "🔐 decrypting ${i}"
    SOPS_AGE_KEY="${age_key}" sops -d "${i}" > "${real_name}"
  done
else
  echo "${age_key_file} not found!"
  exit 1
fi
