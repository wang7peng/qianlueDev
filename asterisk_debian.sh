#!/bin/bash
set -u

# Date: 2024.2.13
# ----- ----- version conf ----- -----
asterisk='21.2.0'
pjproject='2.14'

dahdi='3.3.0'
libpri='1.6.1'
# ----- -----  End of conf  ----- -----

system_requirement() {	
  alembic --version 2> /dev/null # v1.8.1
  if [ $? -eq 127 ]; then sudo apt install -y alembic
  fi

  gawk --version # v5.2
  if [ $? -eq 127 ]; then sudo apt install -y gawk
  fi

  sudo apt install -y build-essential gcc g++ \
    make autoconf automake libtool \
    wget curl

  sudo apt install -y libxml2-utils # it has xmllint

  # use to build dahdi
  sudo apt install -y libglib2.0-dev linux-headers-`uname -r`

  #replace_make

  install_git
  install_python2
}

# v4.3 => v4.4.1
function replace_make {
  make --version 1> /dev/null
  if [ $? -eq 127 ]; then sudo apt reinstall -y make
    replace_make
  fi
  local ver=$(make --version | head --lines=1 | awk '{print $3}')
  if [[ $ver == "4.4.1" ]]; then return 0;
  fi

  local pkgName=make-4.4.1.tar.gz
  local url=https://ftp.gnu.org/gnu/make/$pkgName
  if [ ! -f /opt/$pkgName ]; then
    sudo wget --no-verbose --directory-prefix='/opt' $url 
  fi

  sudo tar -zxf /opt/$pkgName -C /usr/local/src
  cd /usr/local/src/${pkgName%.tar*}
  sudo ./configure
  make 
  sudo make install
  # old make in /usr/bin/, suggest to del it
  sudo rm /usr/bin/make
}

# default 2.39
function install_git {
  git --version 2> /dev/null
  if [ $? -eq 127 ]; then sudo apt install -y git
  fi

  git config --global user.name "wangpeng"
  git config --global user.email "18795975517@163.com"
  git config --global http.sslVerify "false"
  git config --global core.autocrlf input
}

install_python2() {
  python2 -V 2> /dev/null
  if [ $? -ne 127 ]; then return 0
  fi
  
  local pkg='Python-2.7.18.tgz'
  if [ ! -f /opt/$pkg ]; then
    sudo wget -P /opt https://www.python.org/ftp/python/2.7.18/$pkg
  fi
  sudo tar -zxf /opt/Python-2.* -C /usr/local/src

  cd /usr/local/src/Python-2.7.18
  sudo ./configure --enable-optimizations --with-pydebug
  sudo make altinstall
  sudo ln -sfn '/usr/local/bin/python2.7' /usr/bin/python2

  #sudo update-alternatives --config python
}

function download_asterisk {
  local ver='21-current'
  if [ $# -eq 1 ]; then ver=$1
  fi

  local pkg=asterisk-${ver}.tar.gz
  local url=https://downloads.asterisk.org/pub/telephony/asterisk/$pkg

  if [ ! -f /opt/$pkg ]; then sudo wget --directory-prefix='/opt' $url
  fi
  ls -h -og --color=auto /opt
}

function download_dahdi {
  local ver='current'
  local pkg=dahdi-linux-complete-${ver}.tar.gz # 7M

  if [ $# -eq 1 ]; then ver=$1
    pkg=dahdi-linux-complete-${ver}+${ver}.tar.gz
  fi

  local url=https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/$pkg

  if [ ! -f /opt/$pkg ]; then
    echo -e "Downloading package $pkg... \c"
    sudo wget --directory-prefix='/opt' --quiet $url
    echo 'Done'
  fi
}

function download_libpri {
  local ver='1-current'
  if [ $# -eq 1 ]; then ver=$1
  fi

  local pkg=libpri-${ver}.tar.gz
  local url=https://downloads.asterisk.org/pub/telephony/libpri/$pkg

  if [ ! -f /opt/$pkg ]; then
    echo -e "Downloading package $pkg... \c"
    sudo wget --directory-prefix='/opt' --quiet $url
    echo 'Done'
  fi
  ls -h -og --color=auto /opt
}

function build_dahdi {
  sudo apt install -y linux-headers-`uname -r` # 61M

  if [ -f /etc/init.d/dahdi ]; then return 0
  fi

  if [ ! -f /usr/local/src/dahdi-linux-complete-$dahdi+$dahdi ]; then
    sudo tar -xzf /opt/dahdi-linux-complete-* -C /usr/local/src
  fi

  cd /usr/local/src/dahdi-linux-complete-*
  sudo make
  sudo make install
  sudo make install-config
}

function build_libpri {
  if [ ! -d /usr/local/src/libpri-$libpri ]; then
    sudo tar -xzf /opt/libpri-1.* -C /usr/local/src
  fi

  cd /usr/local/src/libpri*
  sudo make 
  sudo make install
  sudo ldconfig
}

# dahdi -> libpri
function install_prereq {
  local pos=`pwd`
  
  download_dahdi $dahdi;
  if [ ! -f /etc/init.d/dahdi ]; then build_dahdi
  fi

  download_libpri $libpri
  sudo ldconfig -p | grep libpri.so
  if [ $? -eq 1 ]; then build_libpri
  fi

  cd /usr/local/src/asterisk-$asterisk

  local op=0
  read -p "install prereq? [Y/n]" op
  case $op in
    1 | Y | y) 
      sudo contrib/scripts/get_mp3_source.sh
      sudo contrib/scripts/install_prereq install ;;
    *)
  esac
  cd $pos
}

# put code in /usr/local/src/asterisk-21.1.0/
function extract_tar2pos {
  # asterisk-21-current.tar.gz
  # asterisk-20.6.0.tar.gz
  local tar=asterisk-${asterisk%%.*}*.tar.gz
  local pos='/usr/local/src'
  if [ $# -gt 0 ]; then tar=$1
  fi

  if [ -d $pos/asterisk-$asterisk ]; then
    echo "don't need extract!"; return 0
  fi

  sudo rm -rf $pos/asterisk-$asterisk
  sudo tar -xzf /opt/$tar -C $pos
}

# 7.5M
function download_pjproject {
  local ver='2.13.1'
  if [ $# -eq 1 ]; then ver=$1
  fi

  local pkg=pjproject-${ver}.tar.bz2
  if [ -f /opt/$pkg ]; then sudo cp /opt/$pkg /tmp
  fi

  # need walk through walls
  if [ ! -f /tmp/$pkg ]; then sudo wget --directory-prefix='/tmp' \
    https://raw.githubusercontent.com/asterisk/third-party/master/pjproject/$ver/$pkg
  fi
}

# build and install
build_asterisk() {
  # configure need pjproject package in /tmp
  download_pjproject $pjproject
 
  cd /usr/local/src/asterisk-$asterisk
  # default prefix=/usr/local
  sudo ./configure

  sudo make menuselect

  local op=0
  read -p "start make? [Y/n]" op
  case $op in
    1 | Y | y) sudo make NOISY_BUILD=yes
      sudo make install
      sudo make samples
      sudo make config
      sudo make install-logrotate
      ;;
    *) 
  esac 

  read -p "need C-API? (default not) [Y/n]" op
  case $op in
    1 | Y | y) 
      sudo make progdocs ;;
    *)
  esac
}

# ----- -----  main point ----- -----
sudo asterisk -V
if [ $? -ne 127 ]; then exit
fi

system_requirement

download_asterisk $asterisk
extract_tar2pos

install_prereq

build_asterisk

sudo systemctl restart asterisk

# last, validate install ok
/etc/init.d/asterisk status
sudo asterisk -V
sudo asterisk -rx 'core show version'

# ----- ----- ----- ----- ----- -----
# Desc: install Asterisk from source
# Plat: Debian 12
#
# Note: put packages in /opt
#       put codes in /usr/local/src/
# ----- ----- ----- ----- ----- -----
