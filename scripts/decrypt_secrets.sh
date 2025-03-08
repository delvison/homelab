#!/usr/bin/env bash

set -e

age_key_file="${HOME}/.config/sops/age/homelab-keys.txt.age"

decrypt_key() {
  if [ -f "${age_key_file}" ]; then 
    echo "[i] Please insert password for ${age_key_file}:"
    [ -z "${SOPS_AGE_KEY}" ] && age_key=$(age -d ${age_key_file})
  else
    echo "${age_key_file} not found!"
    exit 1
  fi
}

decrypt_all_secrets() {
  decrypt_key

  for i in $(find . -name "*.enc"); do 
    real_name=$(echo $i | sed 's/\.enc$//g'); 
    echo "🔐 Decrypting ${i}"
    SOPS_AGE_KEY="${age_key}" sops -d "${i}" > "${real_name}"
  done
}

decrypt_all_secrets
