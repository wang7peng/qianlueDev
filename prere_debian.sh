#!/bin/bash
set -u

# ----- ----- ----- ----- -----
# Env: debain 12
# Desc: asterisk 20.5+
# 
# Note: user asterisk
#       pass like2024
#
# Date: 2024.2.18
# ----- ----- ----- ----- -----

# install mariadb connector
install_connector() {
  if [[ $1 != "mariadb" ]]; then return 0
  fi

  local ver="3.2.1"

  local pkgtar="mariadb-connector-odbc-${ver}-debian-bookworm-amd64.tar.gz"
  if [[ `lsb_release -i --short` == "ubuntu" ]]; then 
    if [[ `lsb_release -c --short` == "jammy" ]]; then
      pkgtar="mariadb-connector-odbc-3.2.1-ubuntu-jammy-amd64.tar.gz" # v22.04
    else
      pkgtar="mariadb-connector-odbc-3.2.1-ubuntu-lunar-amd64.tar.gz"
    fi
  fi

  if [ ! -f /opt/$pkgtar ]; then
    sudo wget -P /opt \
      https://downloads.mariadb.com/Connectors/odbc/connector-odbc-${ver}/$pkgtar
    sudo tar -xzf /opt/mariadb-connector-odbc-*.tar.gz -C /usr/local/src
  fi
  cd /usr/local/src/mariadb-connector-odbc-*

  sudo install lib/mariadb/libmaodbc.so /usr/lib/
  sudo install -d /usr/lib/mariadb/
  sudo install -d /usr/lib/mariadb/plugin/
  sudo install lib/mariadb/plugin/* /usr/lib/mariadb/plugin/
}

add_config() {
  if [[ `whoami` == "root" ]]; then
    sudo echo "" > /etc/odbc.ini
    sudo echo "[asterisk-connector]" >> /etc/odbc.ini 
    sudo echo "Description = MySQL connection to 'asterisk' database" >> /etc/odbc.ini 
    sudo echo "Driver = MariaDB" >> /etc/odbc.ini 
    sudo echo "Database = asterisk" >> /etc/odbc.ini 
    sudo echo "Server = localhost" >> /etc/odbc.ini 
    sudo echo "Port = 3306" >> /etc/odbc.ini 
    sudo echo "Socket = /run/mysqld/mysqld.sock" >> /etc/odbc.ini 
    return 0
  fi

  # sudo echo "xxx" >> /x/file have not effect when bash x.sh without sudo
  echo "[asterisk-connector]" | sudo tee -a /etc/odbc.ini 
  echo "Description = MySQL connection to 'asterisk' database" | tee -a /etc/odbc.ini 
  echo "Driver = MariaDB" | tee -a /etc/odbc.ini 
  echo "Database = asterisk" | tee -a /etc/odbc.ini 
  echo "Server = localhost" | tee -a /etc/odbc.ini 
  echo "Port = 3306" | tee -a /etc/odbc.ini 
  echo "Socket = /run/mysqld/mysqld.sock" | tee -a /etc/odbc.ini 
}

# create db asterisk
create_dbuser() {
  sudo mysql -e "create user 'asterisk'@'%' identified by 'like2024';"
  sudo mysql -e "create database IF NOT EXISTS asterisk;"
  sudo mysql -e "GRANT ALL PRIVILEGES ON asterisk.* TO 'asterisk'@'%';"

  sudo mysql -e "flush privileges;"
}

check_env_db() {
  sudo apt install -y unixodbc unixodbc-dev unixodbc-* # 2.3.11
  sudo apt install -y libltdl-dev
  sudo apt install -y odbcinst

  sudo apt install -y libmariadb-dev

  # libmyodbc8a.so will be put in /usr/lib/x86_64-linux-gnu/odbc/
  sudo apt install -y mysql-connector-odbc

  # add sql source
  local pkgdeb="mysql-apt-config_0.8.29-1_all.deb"
  if [ ! -f /opt/$pkgdeb ]; then
    sudo wget -P /opt \
      http://repo.mysql.com/$pkgdeb
    sudo dpkg -i /opt/mysql-apt-config*
    sudo apt update
  fi

  mysql --version
  if [ $? -eq 127 ]; then sudo apt install -y mysql-server
    sudo systemctl enable mysql
    create_dbuser 'asterisk'
  fi

  install_connector "mariadb"

  # clean and write config k=v into /etc/odbc.ini
  if [ ! -f /etc/odbc.ini ]; then add_config
  fi

  # write into /etc/odbcinst.ini
  odbcinst -q -d
}

# default:
# python with v3.11 has existed
check_env() {
  sudo apt install -y subversion \
    vim curl wget 

  # default add gcc(v12.2) 
  sudo apt install -y build-essential

  install_git
  check_env_db

  sudo apt install -y \
    libnewt-dev libssl-dev libncurses5-dev libsqlite3-dev \
    libjansson-dev libxml2-dev uuid-dev default-libmysqlclient-dev
}

# 3 latest versions exist at the same time in page 
download_asterisk() {
  local ver="21.1.0"
  if [ $# -eq 1 ]; then ver=$1; 
  fi
  local pkg="asterisk-${ver}.tar.gz"

  # curl can not specify dir
  cd /opt
  sudo curl -# -C - -O http://downloads.asterisk.org/pub/telephony/asterisk/$pkg
  ls -al -hog --color=auto # 27M
  sudo tar xvf asterisk-20* -C /usr/local/src
  if [ $? -eq 1 ]; then 
    echo "get source package failure, need download again!"; exit
  fi

  cd /usr/local/src/${pkg%.tar*}

  sudo contrib/scripts/get_mp3_source.sh
  sudo contrib/scripts/install_prereq install
}

build_asterisk() {
  cd /usr/local/src/asterisk-*
  sudo ./configure

  sudo make menuselect

  local op=0
  read -p "make? (default not) [Y/n]" op
  case $op in
    1 | Y | y) sudo make; sudo make install;
      sudo make samples
      sudo make config
      sudo make install-logrotate ;;
    *) exit
  esac

  read -p "need C-API? (default not) [Y/n]" op
  case $op in
    1 | Y | y) 
      sudo make progdocs ;;
    *)
  esac

  sudo ldconfig
}

add_user() {
  local userName="asterisk"
  userName=$1
  sudo groupadd $userName
  sudo useradd -r -d /var/lib/asterisk -g asterisk $userName

  sudo usermod -aG audio,dialout asterisk
  sudo chown -R asterisk:$userName /etc/asterisk
  sudo chown -R asterisk:$userName /var/{lib,log,spool}/asterisk
  sudo chown -R asterisk:$userName /usr/lib/asterisk
}

install_git() {
  sudo apt install -y git #default v2.39

  git config --global user.name "wangpeng"
  git config --global user.email "18795975517@163.com"
  git config --global http.sslVerify "false"
  git config --global core.autocrlf input
}

# install or update go (v1.21+)
install_go() {
  go version 2> /dev/null
  if [ $? -ne 127 ]; then 
    if [[ $1 == `go env GOVERSION` ]]; then 
      return 0; # don't reinstall when their version are consistent
    fi
  fi
  # e.g.  go1.22.3.linux-amd64.tar.gz
  local pkgName=$1.linux-amd64.tar.gz

  if [ ! -f /opt/$pkgName ]; then sudo wget -P /opt  \
    --no-verbose https://go.dev/dl/$pkgName
  fi
  sudo rm -rf /usr/local/etc/go
  sudo tar  -xzf /opt/$pkgName -C /usr/local/etc
  
  cat /etc/profile | grep -i go/bin
  if [ $? -eq 1 ]; then
    echo "export PATH=\$PATH:/usr/local/etc/go/bin" | sudo tee -a /etc/profile
  fi
  echo "remember source /etc/profile, then run this script again!"
  exit
}

# 26 tables will generate in mysql
generate_tables() {
  sudo apt install -y alembic
  # only this can work, not pip install
  sudo apt install -y python3-mysqldb

  cd /usr/local/src/asterisk-2*/contrib/ast-db-manage/
  sudo cp config.ini.sample config.ini
  sudo sed -i '21s/user/asterisk/g'  ../ast-db-manage/config.ini
  sudo sed -i '21s/pass/like2024/g'  ../ast-db-manage/config.ini

  alembic -c ./config.ini upgrade head
}

# ----- ----- main ----- -----

check_env

asterisk -V
if [ $? -ne 127 ]; then

  install_go "go1.22.0"
  go env -w GOPRIVATE=https://go.pfgit.cn
  go env -w GOPROXY=https://proxy.golang.com.cn,direct
  go env -w GO111MODULE=on
  go env -w GOSUMDB=off

  exit
fi

download_asterisk "20.6.0"
build_asterisk

id asterisk
if [ $? -eq 1 ]; then
  add_user "asterisk"
fi

sudo sed -i '8s/.*/AST_USER="asterisk"/' /etc/default/asterisk 
sudo sed -i '9s/.*/AST_GROUP="asterisk"/' /etc/default/asterisk 
sudo sed -i '75s/.*/runuser = asterisk/' /etc/asterisk/asterisk.conf 
sudo sed -i '76s/.*/rungroup = asterisk/' /etc/asterisk/asterisk.conf

# create tables in db
generate_tables

sudo systemctl restart asterisk
sudo systemctl enable asterisk

sudo asterisk -V
