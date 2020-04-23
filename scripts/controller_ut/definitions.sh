#!/bin/bash -e

export JOBS=${JOBS:-$(nproc)}

# use the same kernel definition as for build. copied from contrail-packages/utils/get_kvers.sh
running_kver="$(uname -r)"
if [[ -d "/lib/modules/${running_kver}/build" ]]; then
  # Running kernel's sources are available
  kvers=${running_kver}
else
  # Let's use newest installed version of kernel-devel
  kvers=$(rpm -q kernel-devel --queryformat="%{buildtime}\t%{VERSION}-%{RELEASE}.%{ARCH}\n" | sort -nr | head -1 | cut -f2)
fi
echo "INFO: detected kernel version is $kvers"
ls -l /lib/modules/
export KVERS=$kvers

echo "INFO: Run full build first $(date)"
export CONTRAIL_COMPILE_WITHOUT_SYMBOLS=yes
