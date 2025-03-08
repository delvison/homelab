#!/usr/bin/env bash

for i in $(find . -name "*.enc"); do 
  real_name=$(echo $i | sed 's/\.enc$//g'); 
  echo " Removing ${real_name}"
  rm -rf "${real_name}" || true
done
