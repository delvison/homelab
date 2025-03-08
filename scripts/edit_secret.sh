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

edit_secret() {
  f_edit=$(find . -name "*.enc" | fzf --prompt="Choose a SOPs file to edit")

  decrypt_key

  SOPS_AGE_KEY="${age_key}" sops "${f_edit}"
  echo "${f_edit} has been edited."
}

edit_secret
