#!/bin/bash

set -u

# include: python3 gcc
checkenv() {
  # GNU Awk v5.1
  awk -V 2> /dev/null 1> /dev/null
  if [[ $? -eq 2 || $? -eq 127 ]]; then sudo apt install -y gawk;
  fi
  awk -V | head -n 1

  # default v3.5.2 in Ubuntu1604
  python3 -V 2> /dev/null
  if [ $? -eq 127 ]; then echo "you need to install python3 first!"; exit;
  fi
  G_verPy3=$(python3 -V | awk '{print $2}')
  # e.g. python3.10-dev
  sudo apt install -y python${G_verPy3%.*}-dev

  gcc 2> /dev/null
  if [ $? -eq 127 ]; then echo "you need to install gcc first!"; exit;
    # default v5.3 in Ubuntu1604
    # default v11.4 in Ubuntu2204
  fi
  gcc --version | head -n 1

  swig 2> /dev/null
  if [ $? -eq 127 ]; then sudo apt install -y swig
  fi

  git config --global http.sslVerify false
  git config --global core.autocrlf input
  # other condition
  sudo apt install -y ncurses*   # 6M
}

# 多重检测, 只跑平台 ubuntu 16+
check_sys() {
  # cat /proc/version | grep -q -i "ubuntu"
  grep -i ubuntu --silent /proc/version
  if [ $? -eq 0 ]; then echo `uname --nodename`
  else exit
  fi
}

# rules:
#       ubuntu1604 default -> 2102
#
select_version() {
  local ret=2305
  
  # if Python3 < 3.6, openwrt after v22.03+ can not be installed
  local verCurMid=$(echo $G_verPy3 | tr '.' ' ' | awk '{print $2}')
  if [ $verCurMid -lt 6 ]; then
    ret=2102
  fi

  echo $[ret]
}

# add new lib in openwrt (insert link in the first row)
update_pkg() {
  local op=0
  local content="libqt"
  # qt env
  read -p "add qt5? [Y/n] " op
  case $op in
    Y | y | 1) content=`head --lines=1 feeds.conf.* | awk '{print $2}'`
    # 在首行插入 libqt 的连接
      if [ $content == 'libqt' ]; then echo "libqt ok"
      else
        sed -i '1 i src-git libqt https://github.com/qianlue123/qt5-openwrt.git' feeds.conf.default
      fi;;
    *)
  esac

  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

compile_openwrt() {
  make download -j1 V=s

  local op=1
  read -p "set -j1 for make? (first compile?) [Y/n] " op
  case $op in
    Y | y | 1) make -j1 V=s;;
    2) make -j2;;
    4) make -j4;;
    *) echo "config ok, you can make now!"; exit
  esac
}

# ----- ----- main ----- -----

checkenv

op=0
read -p "Let's compile openwrt in `check_sys`? [Y/n] " op
case $op in
  Y | y | 1) ;;
  *) exit
esac

ver=`select_version` 
branch=openwrt-${ver:0:2}.${ver:0-2}
echo "branch: $branch will be used ..."

dirSrc=openwrt-$ver
if [ ! -d $dirSrc ]; then
  # e.g. xxx  --branch openwrt-23.05 https://github.com/openwrt/openwrt.git openwrt-2305
  git clone --depth 1 --branch $branch https://github.com/openwrt/openwrt.git $dirSrc
fi

cd $dirSrc

update_pkg

make menuconfig

compile_openwrt 

cd ..
