#!/bin/bash
if [ -x "$(command -v yum)" ] ; then
  log "Start cleaning packages"  
  yum clean all -y
  rm -rf /var/cache/yum
  for package in $(rpm -qa | grep -e 'gpg-pubkey' -e 'rdo-release'); do
    rpm -e $package || true
  done
fi
