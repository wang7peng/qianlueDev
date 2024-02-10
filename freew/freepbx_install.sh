#!/bin/bash

# ----- ----- ----- ----- -----
#  platform: ubuntu20
#  Desc: freepbx16 after asterisk18 
#  Date: 2023.12.20
#
# ----- ----- ----- ----- -----

set -u

check_tools() {
  sudo apt install -y subversion \
	  flex bison make \
	  python2.7

  # dot in graphviz
  sudo apt install -y doxygen graphviz \
	  wget curl xmlstarlet alembic
}

check_env() {
  sudo apt install -y libnewt-dev libjansson-dev \
	  libxml2-dev uuid-dev libgsm1-dev libsrtp2-dev \
	  libfftw3-dev libresample1-dev
  
  sudo apt install -y libvpb-dev \
	  libgmime-3*-dev libneon27-dev \
          libgtk2.0-dev # checking for GTK2
}

install_php() {
  sudo apt install -y ca-certificates \
	  apt-transport-https software-properties-common gnupg2
  echo "deb https://packages.sury.org/php/ focal main" | sudo tee /etc/apt/sources.list.d/sury-php.list
  wget -qO - https://packages.sury.org/php/apt.gpg | sudo apt-key add -
  sudo apt install -y php7.4 \
    php7.4-{mysql,cli,common,imap,ldap,xml,fpm,curl,mbstring,zip,gd,gettext,xml,json,snmp}
  sudo apt install -y libapache2-mod-php7.4

  sudo sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/apache2/php.ini
  sudo sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/7.4/cli/php.ini 
  sudo sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php/7.4/apache2/php.ini 
}

# add a user in group asterisk
add_user() {
  local userName="asterisk"
  userName=$1

  cat /etc/group | grep asterisk 1> /dev/null
  if [ $? -eq 1 ]; then sudo groupadd asterisk
  fi

  # create user asterisk in group asterisk
  groups asterisk | grep $userName 1> /dev/null
  if [ $? -eq 1 ]; then
    sudo useradd -r -d /var/lib/asterisk -g asterisk $userName
  fi

  groups asterisk | grep audio
  if [ $? -eq 1 ]; then
    sudo usermod -aG audio,dialout asterisk
  fi

  sudo chown -R asterisk.$userName /etc/asterisk
  sudo chown -R asterisk.$userName /var/{lib,log,spool}/asterisk
  sudo chown -R asterisk.$userName /usr/lib/asterisk
}

install_asterisk18() {
  # must to see it's website, freepbx not support v20+
  local ver="18.16.0"
  pkgName=asterisk-$ver.tar.gz
  if [ ! -f $pkgName ]; then wget --no-verbose \
    https://downloads.asterisk.org/pub/telephony/asterisk/old-releases/$pkgName
    tar -zxf $pkgName
  fi
  sudo chmod 777 asterisk-$ver

  cd asterisk-$ver
  sudo contrib/scripts/get_mp3_source.sh
  sudo contrib/scripts/install_prereq install

  ./configure
  make menuselect

  local op=0
  read -p "make and install? [Y/n] " op
  case $op in
    Y | y | 1) sudo make
          sudo make install;;
    *) echo "need create user to run service"
  esac

  sudo make samples
  sudo make config
  sudo ldconfig

  cd ..
}


install_freepbx() {
  wget https://mirror.freepbx.org/modules/packages/freepbx/7.4/freepbx-16.0-latest.tgz
  sudo tar -xzf freepbx-16.0-latest.tgz
  cd freepbx
  sudo systemctl stop asterisk
  sudo ./start_asterisk start

  sudo apt install -y nodejs npm
  sudo ./install -n

  sudo fwconsole ma disablerepo commercial
  sudo fwconsole ma installall
  sudo fwconsole ma delete firewall
  sudo fwconsole reload
  sudo fwconsole restart
}

# ----- ----- main ----- -----

check_tools
check_env
install_php

asterisk -V
if [ $? -eq 127 ]; then install_asterisk18
fi

add_user "asterisk"
sudo sed -i '8s/.*/AST_USER="asterisk"/' /etc/default/asterisk 
sudo sed -i '9s/.*/AST_GROUP="asterisk"/' /etc/default/asterisk 
sudo sed -i '75s/.*/runuser = asterisk/' /etc/asterisk/asterisk.conf 
sudo sed -i '76s/.*/rungroup = asterisk/' /etc/asterisk/asterisk.conf

sudo systemctl restart asterisk
sudo systemctl enable asterisk

sudo apt install -y apache2
sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bk

sudo sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

op=0
read -p "start install freepbx? [Y/n] " op
case $op in
  Y | y | 1) install_freepbx;;
  *) exit
esac

sudo a2enmod rewrite
sudo systemctl restart apache2

echo "install ok, remember check ufw"
echo "now you can open 127.0.0.1/admin to login!"
