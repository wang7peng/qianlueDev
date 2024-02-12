#!/bin/bash

set -u

# ----- ----- version conf ----- -----
go='1.22.0'

# ----- ----- -----  ----- ----- -----

# wget tree ... 
function check_tools {
  wget --version | 2> /dev/null
  if [ $? -eq 127 ]; then sudo yum install -y wget
  fi

  tree --version | 2> /dev/null
  if [ $? -eq 127 ]; then sudo yum install -y tree
  fi

  vim --version | 2> /dev/null
  if [ $? -eq 127 ]; then sudo yum install -y vim
  fi
}

# download tar
# $1  pkgName
# e.g wget -P /opt xxx/go1.22.0.linux-amd64.tar.gz
function download_go {
  local ver='go1.22.0'
  if [ $# -eq 1 ]; then ver=$1
  fi
  
  local pkg=${ver}.src.tar.gz
  if [[ `arch` == 'x86_64' ]]; then pkg=${ver}.linux-amd64.tar.gz
  fi

  local url=https://go.dev/dl/$pkg
  if [ ! -f /opt/$pkg ]; then sudo wget \
    --directory-prefix='/opt' --no-verbose $url
  fi
}

# tar pkg to solid path
# e.g tar -zxf xxx.tar.gz -C /usr/local/src
function tar2pos {
  local pos='/usr/local/etc'
  if [ $# -eq 1 ]; then pos=$1
  fi

  # check whether go dir exist or not in dst pos
  if [ -d $pos/go ]; then
    local oldver=`$pos/go/bin/go env GOVERSION`

    if [[ $oldver == go$go ]]; then
      echo "$oldver don't need update!"; return 0
    fi
  fi 

  sudo rm -rf $pos/go;
  sudo tar -xzf /opt/go$go.*.tar.gz -C $pos
}

# add a item value to PATH
# echo 'export PATH=\$PATH:xxx' | sudo tee -a /etc/profile.d/xxx.sh
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

install_go() {
  # step 1
  download_go go$go # go1.22.0
  ls -h -og --color=auto /opt

  # step 2
  tar2pos "/usr/local/etc"

  # step 3
  addenv2path "/usr/local/etc/go/bin"

  # step 4
  go env -w GOPRIVATE=https://go.pfgit.cn
  go env -w GOPROXY=https://proxy.golang.com.cn,direct
  go env -w GO111MODULE=on
  go env -w GOSUMDB=off
}

# ----- ----- main ----- -----
check_tools

install_go
