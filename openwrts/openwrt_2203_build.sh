#!/bin/bash

# ----- ----- ----- ----- ----- -----
#  platform: ubuntu22 (with base tools)
#  Desc: openwrt2203 + mt7621 
#  Date: 2023.12.06
# ----- ----- ----- ----- ----- -----

set -u

update_env() {
  local op=0
  read -p "update env again? [Y/n] " op 
  case $op in
    Y | y | 1)
     ./scripts/feeds update -a
     ./scripts/feeds install -a
     if [ $? -ne 0 ]; then exit;
     fi
     ;;
    *)
  esac
}

check_sys() {
  # cat /proc/version | grep -q -i "ubuntu"
  grep -i ubuntu --silent /proc/version
  if [ $? -eq 0 ]; then echo "ubuntu"
  else echo "unknown"
  fi
}

config_git() {
  git config --global http.postBuffer 524288000
  git config --global http.lowSpeedLimit 1000
  git config --global http.lowSpeedTime 600
}


# ----- ----- main ----- -----
config_git

op=0
read -p "Let's compile openwrt in `check_sys`? [Y/n] " op
case $op in
  Y | y | 1) ;;
  *) exit
esac

ver="22.03.6"

dirSrc=openwrt-$ver

# download
pkgSrc=${dirSrc}.tar.gz  # openwrt-22.03.6.tar.gz
if [ ! -f $pkgSrc ]; then
  wget --no-verbose -O $dirSrc.tar.gz  \
       	https://github.com/openwrt/openwrt/archive/refs/tags/v22.03.6.tar.gz # 7.7M
fi

if [ ! -d $dirSrc ]; then tar -xzf $dirSrc.tar.gz 
fi

# get official conf file with special version
if [ ! -f $ver.config ]; then
  wget --no-verbose -O $ver.config \
	https://downloads.openwrt.org/releases/$ver/targets/ramips/mt7621/config.buildinfo

  if [ $? -eq 8 ]; then rm $ver.config; exit
  fi
fi

checkit=`sha256sum $ver.config`
if [ ${checkit:0:6} != "abbd6c" ]; then exit;
fi

cd $dirSrc

op=0
read -p "official conf $ver have get! use it? [Y/n] " op 
case $op in
  Y | y | 1) cp ../$ver.config ./.config;;
  *)
esac

update_env

make menuconfig

op=0
read -p "make download -j1? [Y/n] " op 
case $op in
  Y | y | 1) make download -j1 V=s
    echo $?
    ;;
  *)
esac

op=0
read -p "start make -jx? [Y/n] " op 
case $op in
  Y | y | 1) make -j1 V=s;;
  2) make -j2;;
  *) echo "config ok, you can make now!"
esac

cd ..
