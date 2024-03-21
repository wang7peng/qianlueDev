#!/bin/bash

set -u

# ----- ----- ----- ----- ----- -----
#  platform: centos7 (with base tools)
#  Desc: 安装完 freepbx.iso 后增加设置
#
#  Note: root运行
# ----- ----- ----- ----- ----- -----

####################  version  control  ####################
git='2.44.0'
go='1.22.1'
python='3.12.2'
############################################################

replace_gcc() {
  local infoGCC=$(gcc --version | head --lines=1 | awk '{print $3}')
  local verMax=${infoGCC%%.*}
  if [ $verMax -gt 9 ]; then 
    gcc --version | head --lines=1; return 0; 
  fi

  local op=0
  read -p "start update gcc? [Y/n] " op
  case $op in
    Y | y | 1) ;;
    *) return 0;
  esac

  yum install -y centos-release-scl
  yum install -y devtoolset-11-binutils devtoolset-11-gcc* 
  scl enable devtoolset-11 bash

  source /opt/rh/devtoolset-11/enable
  echo "source /opt/rh/devtoolset-11/enable" >> /etc/profile

  rm -rf /usr/bin/gcc /usr/bin/g++
  ln -s /opt/rh/devtoolset-11/root/bin/gcc /usr/bin/gcc
  ln -s /opt/rh/devtoolset-11/root/bin/g++ /usr/bin/g++

  echo "please source /etc/profile , then run this script again!"
  exit
}

install_git() {
  git -v 2> /dev/null
  if [ $? -ne 127 ]; then return 0; fi

  local pkg=git-${git}.tar.gz
  local url=https://mirrors.edge.kernel.org/pub/software/scm/git/$pkg
  sudo wget --no-verbose --directory-prefix='/opt' -nc $url

  # 安装 openssl 时会顺带自动安装 zlib-devel 等其他依赖库
  yum -y install curl-devel expat-devel openssl-devel 
  sudo tar -C /usr/local/src -zxf /opt/git-2.4*
  cd /usr/local/src/git-2.4*
  make
  make install 
}

# v3.82 => v4.4
replace_make() {
  make --version 1> /dev/null
  if [ $? -eq 127 ]; then sudo yum reinstall -y make
    replace_make
  fi
  local ver=$(make --version | head --lines=1 | awk '{print $3}')
  if [[ $ver != "3.82" ]]; then return 0;
  fi

  local pkgName=make-4.4.1.tar.gz
  if [ ! -f /opt/$pkgName ]; then sudo wget --no-verbose -P /opt \
    https://ftp.gnu.org/gnu/make/$pkgName
  fi
  sudo tar -zxf /opt/$pkgName -C /usr/local/src
  local pos=`pwd`
  cd /usr/local/src/${pkgName%.tar*}
  sudo ./configure
  make 
  sudo make install
  # old make in /usr/bin/, suggest to del it
  rm /usr/bin/make
  cd $pos
}

# only python2.7.5 existed by default
install_python() {
  python3 --version 1> /dev/null &2> 1
  if [ $? -ne 127 ]; then
    local verMid=$(python3 --version | tr '.' ' ' | awk '{print $3}') 
    if [ $verMid -gt 11 ]; then return 0;
    fi
  fi

  local ver=$python
  local pkgName=Python-$ver.tar.xz
  if [ ! -f /opt/$pkgName ]; then sudo wget --no-verbose -P /opt \
    https://www.python.org/ftp/python/${ver}/$pkgName
  fi
  sudo tar -xf /opt/$pkgName -C /usr/local/src

  yum install -y openssl-devel 
  local pos=`pwd`
  cd /usr/local/src/${pkgName%.tar*}
  ./configure --with-ssl
  make 
  sudo make install
  cd $pos
}

# same: echo 'export PATH=$PATH:/usr/local/etc/go/bin' >> /etc/profile
function addenv2path {
  local confFile='/etc/profile.d/wangpeng.sh'
  if [ ! -f $confFile ]; then sudo touch $confFile
  fi
  
  if [ $(grep 'go/bin' $confFile | wc -l) -eq 0 ]; then
    echo "export PATH=\$PATH:$1" | sudo tee -a $confFile
  fi
  echo $PATH | tr ':' '\n'

  if [ $(echo $PATH | tr ':' '\n' | grep 'go/bin' | wc -l) -eq 0 ]; then
    # source /etc/profile
    echo "remember source /etc/profile, then run this script again!"
    exit 
  fi
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
  sudo tar -C /usr/local/etc -xzf /opt/$pkgName

  addenv2path "/usr/local/etc/go/bin"
}

# ----- ----- main ----- -----
sudo yum install -y lrzsz \
  bison flex texinfo

replace_make
replace_gcc

install_git

git config --global user.name "wangpeng"
git config --global user.email "18795975517@163.com"
git config --global http.sslVerify "false"
git config --global core.autocrlf input

install_python

install_go "go$go"

go env -w GOPRIVATE=https://go.pfgit.cn
go env -w GOPROXY=https://proxy.golang.com.cn,direct
go env -w GO111MODULE=on
go env -w GOSUMDB=off
