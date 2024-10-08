#!/bin/bash

set -u

# include: tar awk
init_tools() {
  sudo apt-get update

  bash ../apps/git_ubuntu.sh
  git config --global core.autocrlf input
  # avoid get a prompt: xxx verification failed
  git config --global http.sslVerify "false"

  tar --version 1> /dev/null
  if [ $? -eq 127 ]; then sudo apt install -y tar
  fi

  awk -V 2> /dev/null 1> /dev/null
  if [[ $? -eq 2 || $? -eq 127 ]]; then sudo apt install -y gawk;
  fi
  # awk -V | head -n 1
  awk --version | head --lines=1

  # 代码不要支持c++17, gcc-11+ 默认支持 c++17，需要 gcc10以下版本 
  verGcc=$(gcc --version | head --lines=1 | awk '{print $4}')
  if [ ${verGcc%%.*} -ge 11 ]; then 
    sudo apt install -y gcc-10 g++-10
    sudo rm -rf /usr/bin/gcc /usr/bin/g++
    sudo ln -s /usr/bin/gcc-10 /usr/bin/gcc
    sudo ln -s /usr/bin/g++-10 /usr/bin/g++
  fi
  gcc --version | head --lines=1

  sudo apt-get install -y \
    libncurses5-dev subversion libssl-dev libxml-parser-perl \
    unzip wget xz-utils build-essential ccache gettext xsltproc  
  sudo apt install -y zlib1g zlib1g-dev # not zlibc

  sudo apt install -y openjdk-8-jdk
}

# install 32bit base tool such as ncurses in 64 system
init_64need32() {
  local sysBit=`getconf LONG_BIT`
  if [ $sysBit -eq 64 ]; then
    sudo dpkg --add-architecture i386
    sudo apt-get update
    sudo apt-get install -y libc6:i386 libstdc++6:i386
    # libncurses5:i386 not exist in ubuntu23+
    sudo apt-get install -y lib32ncurses-dev
    sudo apt-get install -y lib32z1
  fi
}

# 
install_uboot() {
  if [ ! -d u-boot-hiwooya ]; then
    git clone --depth 1 https://github.com/hi-wooya/u-boot-hiwooya.git
  else
    echo "repo u-boot have downloaded!"
  fi
  local op=0
  read -p "need to install u-roob? [Y/n] " op
  case $op in
    Y | y | 1) cd u-boot*
      sudo rm -rf /opt/buildroot-gcc342 2> /dev/null
      if [ ! -d '/opt/mips-2012.03' ]; then
        sudo tar xfj buildroot-gcc* -C /opt/
        echo "tar content of gcc342--> /opt ok"
        # rename cross gcc to default dir 
        # sudo mv '/opt/buildroot-gcc342/' '/opt/mips-2012.03'
      fi
      make clean
      # only 7628, error will appears if select 7621
      make menuconfig 
      make 
    cd .. ;;
    *) echo "- u-boot \t ok!"
  esac
}

install_openWrt() {
  ./scripts/feeds update -a
  ./scripts/feeds install -a
  # use default config directly
  sudo rm .config 2> /dev/null
  cp config-HIWOOYA16128 .config

  make menuconfig
  # don't use -j8 directly, otherwise some package will download failed!
  make download -j1 V=s
  if [ $? -ne 0 ]; then 
    echo "may be need to change git:// with https://"
  else
    make V=99
  fi
}

# ----- ----- main ----- -----

init_tools

init_64need32
install_uboot
bash ../language/python2_install.sh

if [ ! -d 'openwrt-hiwooya'  ]; then
  git clone --depth 1 https://github.com/hi-wooya/openwrt-hiwooya.git
else
  echo "repo openwrt have downloaded!"
fi

cd openwrt-hiwooya
# only compile it when the suffix .bin file not exist
numbers=`find bin/ -maxdepth 2 | grep '.bin' | wc -l`
if [ $numbers -lt 1 ]; then install_openWrt
fi

ls -sh --color=auto bin/*/ 2> /dev/null
if [ $? -eq 2 ]; then echo "compile failure." 
fi

cd ..
