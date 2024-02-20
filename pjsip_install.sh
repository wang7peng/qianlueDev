#!/bin/bash

set -u

#  platform: ubuntu22

# ----- ----- version conf ----- -----
pjproject='2.14'
opus='1.4'

pkg=pjproject-${pjproject}.tar.gz # 9.8M
pkg_opus=opus-$opus.tar.gz        # 1M
# ----- ----- -----  ----- ----- -----

# install latest gnu make
install_make() {
  if [ ! -f make.tar.gz ]; then
    wget --no-verbose --tries=1	-O 'make.tar.gz' \
      https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz # 2.2M
  fi
  tar -zxf make.tar.gz
  cd make-*
  ./configure
  make
  sudo make install
  make -v
}

check_env() {
  sudo apt-get install -y libasound2-dev
  sudo apt install -y libssl-dev libgl-dev

  # check gnu C
  gcc 2> /dev/null
  if [ $? -eq 127 ];then sudo apt install -y gcc g++
  fi
  gcc --version | head -n 1

  # check gnu make
  make -v 1> /dev/null 2> /dev/null
  if [ $? -eq 127 ]; then sudo apt install -y make
  fi

  # make -v | head -n 1
  local ver=$(make --version | head --lines=1 | awk '{print $3}')
  if [ ${ver%%.*} -lt 4 ]; then install_make
  fi  
}

# opus 源码编译
# 安装完成会在源码总目录产生 opus_demo, 没有额外bin目录
install_opus() {
  local url=https://downloads.xiph.org/releases/opus/$pkg_opus

  # 不能在终端直接使用 opus_demo 命令, 因为没有自动装到 /xxx/bin
  local c=`sudo find /usr/local -name opus_demo | wc -l`
  if [ $c -gt 0 ]; then return 0; fi

  if [ ! -f /opt/$pkg_opus ]; then
    sudo wget --directory-prefix='/opt' --no-verbose $url
  fi

  sudo rm -rf /usr/local/src/opus-$opus
  sudo tar -xzf /opt/$pkg_opus -C /usr/local/src

  cd /usr/local/src/opus-$opus
  # 生成的两个目录 include 和 lib 直接和 /usr/local 下的合并
  # 如果单独存放到其他地方，需要额外设置环境变量
  ./configure --prefix=/usr/local/
  make
  sudo make install
}

# get pkg of pjsip
#
download_pj() {
  local pkg_tag=${pjproject}.tar.gz
  local url=https://github.com/pjsip/pjproject/archive/refs/tags/$pkg_tag

  # wget -nc 已存在文件不下载, 只要包名中含有对应版本号, 不用担心新旧包重名
  sudo wget --no-clobber --no-verbose -O /opt/$pkg $url

  ls -h -og --color=auto /opt
}

build_pj() {
  cd /usr/local/src/pjproject-${pjproject}

  sudo ./configure --prefix=/usr/local/etc/pjsip

  local op=0
  read -p "start make? [Y/n] " op
  case $op in
    Y | y | 1) sudo make dep
      sudo make;;
    *) return 0
  esac

  sudo make install
}

# ----- ----- main ----- -----
check_env

install_opus # must

download_pj

cd /usr/local/src
if [ ! -d pjproject-${pjproject} ]; then
  sudo tar -xzf /opt/$pkg -C /usr/local/src
fi

build_pj

echo "install ok, clear yourself"
