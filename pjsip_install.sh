#!/bin/bash

set -u

#  platform: ubuntu22

# ----- ----- version conf ----- -----
pjproject='2.14'

pkg=pjproject-${pjproject}.tar.gz # 9.8M
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

# opus v1.4
install_opus() {
  if [ ! -f 'opus-1.4.tar.gz' ]; then
    wget --no-verbose --tries=1	-O 'opus.tar.gz' \
      https://downloads.xiph.org/releases/opus/opus-1.4.tar.gz # 1.1M
  else
    echo "pkg opus-1.4 have downloaded!"
  fi

  tar -xzf opus.tar.gz
  cd opus-1.4
  # 生成的两个目录 include 和 lib 直接和 /usr/local 下的合并
  # 如果单独存放到其他地方，需要额外设置环境变量
  ./configure --prefix=/usr/local/
  make
  sudo make install
  cd ..
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

  make dep
  make
  sudo make install
}

# ----- ----- main ----- -----
check_env

op=0
read -p "add additional lib opus? [Y/n] " op
case $op in
  Y | y | 1) install_opus;;
  *)
esac 

download_pj

cd /usr/local/src
if [ ! -d pjproject-${pjproject} ]; then
  sudo tar -xzf /opt/$pkg -C /usr/local/src
fi

build_pj

echo "install ok, clear yourself"
