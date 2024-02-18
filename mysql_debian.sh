#!/bin/bash

set -u

# Desc: install mysql8 in Debian/Ubuntu
# Platform: debian 12
# Date: 2024.2.17
# ----- ----- ----- -----

# default not mysqldb exist in apt
# need add it by downloading, then apt ok 
function addsource_db {
  local pkg='mysql-apt-config_0.8.29-1_all.deb'

  local val=$(apt policy mysql-server | grep -i candidate | cut -d: -f 2)
  if [[ $val != ' (none)' ]]; then return 0
  fi

  local sys='debian'
  if [ `hostnamectl | grep -i ubuntu | wc -l` -eq 1 ]; then sys='ubuntu'
  fi

  local url=https://repo.mysql.com/apt/${sys}
  url=$url/pool/mysql-apt-config/m/mysql-apt-config/$pkg
  # sudo wget -P /opt https://.../xxx_all.deb
  if [ ! -f /opt/$pkg ]; then
    sudo wget --directory-prefix='/opt' $url
    ls -h -og --color=auto /opt
  fi

  sudo dpkg -i /opt/$pkg; sudo apt update -y
}

install_mysql8() {
  sudo mysql --version
  # 命令本身不存在是127, 带 sudo 时是 1
  if [ $? -ne 1 ]; then return 0
  fi

  addsource_db
  sudo apt install -y mysql-server
  sudo systemctl enable mysql
}

# sudo mysql -e "DROP user $user@'%', $user@localhost ;"
# $1 user
function drop_dbuser {
  if [ $# -eq 0 ]; then echo "use function fail!"; exit
  fi

  local user=$1
  local cmd="select user,host from mysql.user where user='$user' and host='%';"
  if [ $(sudo mysql -Ne "$cmd" | wc -l) -eq 1 ]; then
    sudo mysql -e "DROP user $user@'%';"
  fi

  cmd="select user,host from mysql.user where user='$user' and host='localhost';"
  if [ $(sudo mysql -Ne "$cmd" | wc -l) -eq 1 ]; then
    sudo mysql -e "DROP user $user@localhost;"
  fi
}

create_dbuser() {
  user=`whoami`
  if [ $# -eq 1 ]; then user=$1
  fi

  drop_dbuser $user
  sudo mysql -e "create user $user@'%' identified by 'like2024';"

  sudo mysql -e "create database IF NOT EXISTS asterisk;"
  sudo mysql -e "create database IF NOT EXISTS qianlue;"
  sudo mysql -e "GRANT ALL PRIVILEGES ON asterisk.* TO $user@'%';"
  sudo mysql -e "GRANT ALL PRIVILEGES ON qianlue.* TO $user@'%';"

  sudo mysql -e "flush privileges;"
}

# login directly with cmd 'mysql -u user'
# when dbuser name as same as linux, login with cmd 'mysql'
create_dbuser_nopass() {
  local user=`whoami`
  if [ $# -eq 1 ]; then
    if [[ $user != $1 ]]; then user=$1
    fi
  fi

  drop_dbuser $user
  if [[ $user != `whoami` ]]; then
    sudo mysql -e "CREATE user $user@localhost identified by '';"
  else
    sudo mysql -e "CREATE user $user@localhost identified with 'auth_socket';"
  fi

  sudo mysql -e "create database IF NOT EXISTS asterisk;"
  sudo mysql -e "create database IF NOT EXISTS qianlue;"
  sudo mysql -e "GRANT ALL PRIVILEGES ON asterisk.* TO $user@localhost;"
  sudo mysql -e "GRANT ALL PRIVILEGES ON qianlue.* TO $user@localhost;"
  
  sudo mysql -e "flush privileges;"
}

# ----- ----- main ----- -----
install_mysql8

create_dbuser 'wangpeng'
create_dbuser_nopass 'astmin'

sudo mysql -e "select host,user,plugin from mysql.user;"
