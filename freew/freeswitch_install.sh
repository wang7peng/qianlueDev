#!/bin/bash

# ----- ----- ----- ----- -----
# platform: ubuntu20
#
# refer: www.cnblogs.com/tangm421/p/17622894.html
#        computingforgeeks.com/how-to-install-freeswitch-pbx-on-ubuntu/
# ----- ----- ----- ----- -----

set -u

# must exist: automake cmake
check_tool() {
  sudo apt install -y autoconf automake yasm \
	  build-essential libtool libtool-bin pkg-config \
    python3-distutils

  cmake --version 1> /dev/null 2> /dev/null
  if [ $? -eq 127 ]; then echo "install cmake first!"; exit
  fi
  cmake --version | head --lines=1
}

check_env() {
  TOKEN="pat_kdfVXr4YGy1Edda7pnjGm8An"
  sudo apt-get update 
  sudo apt-get install -yq gnupg2 wget lsb-release
  
  sudo wget --http-user=18795975517@163.com --http-password=$TOKEN -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg
  sudo chmod 666 /etc/apt/auth.conf
  sudo echo "machine freeswitch.signalwire.com login signalwire password $TOKEN" > /etc/apt/auth.conf
  sudo chmod 666 /etc/apt/auth.conf

  sudo echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list

  sudo echo "deb-src [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" >> /etc/apt/sources.list.d/freeswitch.list

  sudo apt-get update
  sudo apt-get build-dep freeswitch
}

install_libpcap() {
  local pkgName=libpcap-1.10.4.tar.gz
  if [ ! -f $pkgName ]; then
    wget --no-verbose https://www.tcpdump.org/release/$pkgName
  fi
  tar -xzf $pkgName
  cd ${pkgName%.tar*}
  ./configure
  make 
  sudo make install
  cd ..
}

check_env2() {
  sudo apt install -y \
        zlib1g-dev libcurl4-openssl-dev libpcre3-dev \
       	libncurses5 libncurses5-dev libasound2-dev libgdbm-dev  \
       	libopus-dev libspeex-dev libspeexdsp-dev libldns-dev libssl-dev \
        libshout-dev libmpg123-dev libmp3lame-dev \
       	libsndfile1-dev libopus-dev libedit-dev libnode-dev

  # picture
  sudo apt install -y \
	  libtiff-dev libtiff5-dev libjpeg-dev

  sudo apt install --yes build-essential \
	  unzip unixodbc-dev ntpdate libxml2-dev sngrep

  sudo apt install --yes e2fsprogs-l10n # it has uuid/uuid.h

  sudo sudo apt install -y libexpat1-dev libogg-dev \
    libgnutls28-dev libx11-dev libvorbis-dev 

  ldconfig -p | grep libpcap.so
  if [ $? -eq 1 ]; then install_libpcap
  fi
}

install_db() {
  sudo apt install -y libdb-dev unixodbc-dev
  sudo apt install -y \
	  libpq-dev libpq5 \
	  libmongoc-dev mariadb-server libsqlite3-dev
}

install_module-ffmpeg() {
  sudo apt install -y \
    libavresample-dev libavformat-dev libswscale-dev

  sudo apt install -y libx264-dev libvlc-dev
}

install_module-languages() {
  # java
  # TODO

  # lua
  sudo apt install -y liblua5.3-dev liblua5.2-dev liblua5.2-0
  sudo apt install -y libperl-dev python-dev 
}

install_libks() {
  sudo apt install -y uuid-dev

  cd /usr/local/src
  if [ ! -d libks ]; then
    # Don't add --depth 1
    sudo git clone https://github.com/signalwire/libks.git
  fi
  cd libks
  sudo cmake . 
  sudo make
  sudo make install
  sudo ldconfig 
  cd ~/Desktop  
}

install_signalwire() {
  cd /usr/local/src
  if [ ! -d "signalwire-c" ]; then
    sudo git clone https://github.com/signalwire/signalwire-c.git
  fi
  cd signalwire-c
  sudo cmake .
  sudo make
  sudo make install
  sudo ldconfig 
  cd ~/Desktop
}

# need version 3.0+
install_spanDSP() {
  sudo apt install -y libtiff-dev
  
  if [ ! -d spandsp ]; then
    git clone --depth 35 https://github.com/freeswitch/spandsp.git
  fi
  cd spandsp
  git checkout 0d2e6ac
  ./bootstrap.sh
  ./configure
  make
  sudo make install
  sudo ldconfig
  cd ..
}

# need version 1.13+
install_sofiaSip() {
  local v="v1.13.17"

  cd /usr/local/src
  if [ ! -d sofia-sip ]; then
    sudo git clone -b $v --depth 1 https://github.com/freeswitch/sofia-sip.git
  fi
  cd sofia-sip
  sudo ./bootstrap.sh
  sudo ./configure
  sudo make
  sudo make install
  sudo ldconfig
  cd ~/Desktop
}

# ----- ----- main ----- -----

op=0
read -p "never check env? [Y/n] " op
case $op in
  N | n | 0);;
  *) check_tool; check_env2
     install_db
     install_module-ffmpeg
     install_module-languages

     sudo apt autoremove -y
esac

# install libks first
# use libks directly will match libksba
ldconfig -p | grep libks2.so
if [ $? -eq 1 ]; then install_libks
fi

ldconfig -p | grep signalwire
if [ $? -eq 1 ]; then install_signalwire
fi

ldconfig -p | grep spandsp
if [ $? -eq 1 ]; then install_spanDSP
fi

ldconfig -p | grep sofia-sip
if [ $? -eq 1 ]; then install_sofiaSip
fi

cd ~/Desktop

pkgName=freeswitch-1.10.10.-release.tar.xz
if [ ! -f $pkgName ]; then wget --no-verbose \
  https://files.freeswitch.org/freeswitch-releases/$pkgName
fi
if [ ! -d ${pkgName%.tar*} ]; then tar -xf $pkgName
fi

#if [ ! -d freeswitch ]; then
#  git clone --depth 2 --branch v1.10 https://github.com/signalwire/freeswitch.git
#fi

cd ${pkgName%.tar*}

./bootstrap.sh -j

./configure

op=0
read -p "start make and install? [Y/n] " op
case $op in
  Y | y | 1) make;;
  *) exit
esac

sudo make install
sudo make cd-sounds-install
sudo make cd-moh-install 

cd ..

# setup env
sudo rm /usr/local/bin/freeswitch /usr/local/bin/fs_cli
sudo ln -s /usr/local/freeswitch/bin/freeswitch /usr/local/bin/
sudo ln -s /usr/local/freeswitch/bin/fs_cli /usr/local/bin/

echo "export PATH=\$PATH:/usr/local/freeswitch/bin" >> ~/.bashrc
source ~/.bashrc

echo  "try running: sudo freeswitch -nonat "
