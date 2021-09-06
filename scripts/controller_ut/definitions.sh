#!/bin/bash -e

export JOBS=${JOBS:-$(nproc)}

# use the same kernel definition as for build. copied from contrail-packages/utils/get_kvers.sh
running_kver="$(uname -r)"
if [[ -d "/lib/modules/${running_kver}/build" ]]; then
  # Running kernel's sources are available
  kvers=${running_kver}
else
  # Let's use newest installed version of kernel-devel
  # NOTE:
  # Filter by 3.10.0 kernel. In case of 4.18 kernel UT fails because of
  # gcc version that doesnt support __has_attribets and alike.
  # Switch to the fresh version of gcc is not possible for now for UT as
  # it breaks other UT (python cannot build some own modules needed for test)
  kvers=$(rpm -q kernel-devel --queryformat="%{buildtime}\t%{VERSION}-%{RELEASE}.%{ARCH}\n" | sort -nr | grep '3.10.0' | head -1 | cut -f2)
fi
echo "INFO: detected kernel version is $kvers"
ls -l /lib/modules/
export KVERS=$kvers

export CONTRAIL_COMPILE_WITHOUT_SYMBOLS=yes
