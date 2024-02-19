#!/usr/bin/env bash

set -e

age_key_file="${HOME}/.config/sops/age/homelab-keys.txt.age"

if [ -f "${age_key_file}" ]; then 
  f_edit=$(find . -name "*.enc" | fzf --prompt="Choose a SOPs file to edit")

  echo "[i] Please insert homelab-key password:"
  [ -z "${SOPS_AGE_KEY}" ] && age_key=$(age -d ${age_key_file})

  SOPS_AGE_KEY="${age_key}" sops "${f_edit}"
  echo "${f_edit} has been edited."
else
  echo "${age_key_file} not found!"
  exit 1
fi
