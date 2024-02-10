#!/bin/bash

set -u

# include: awk tree wget vim ncurses
init_tools() {
  # GNU Awk v5.1
  awk -V 2> /dev/null 1> /dev/null
  if [[ $? -eq 2 || $? -eq 127 ]]; then sudo apt install -y gawk;
  fi
  awk -V | head -n 1

  # 一开始不装也通过验证, 在后期 make 的时候才被检测到, 不装不行
  swig 2> /dev/null
  if [ $? -eq 127 ]; then sudo apt install -y swig
  fi
  swig -version | head --lines=2 # first line have null strings 

  tree --version 1> /dev/null
  if [ $? -eq 127 ]; then sudo apt install -y tree
  fi

  wget -V 1> /dev/null
  if [ $? -eq 127 ]; then sudo apt install -y wget
  fi

  vim --version 1> /dev/null
  if [ $? -eq 127 ]; then sudo apt install -y vim
  fi
 
  sudo apt install -y libncurses5-dev libz-dev
}

# v2.43+
install_git() {
  git -v 1> /dev/null 2> /dev/null
  if [ $? -eq 127 ]; then
    # if not use this repo, default 2.40 will be installed
    sudo add-apt-repository ppa:git-core/ppa
    sudo apt update
    sudo apt install git -y
  else
    echo "- git \t\t ok!"
  fi
}

# v3.27+
install_cmake() {
  cmake -version 1> /dev/null 2> /dev/null
  if [ $? -eq 127 ]; then
    sudo apt install cmake
  else
    echo "- cmake \t ok!"
  fi
}

# v13.2+
install_gnu() {
  # ignore the prompt (fatal error: not input files)
  gcc 2> /dev/null
  if [ $? -eq 127 ]; then
    # default v9.4 in ubuntu 20.04
    sudo apt install -y gcc g++
  else
    echo "- c/c++ \t ok!"
  fi
}

# v1.21+
install_go() {
  go version 1> /dev/null 2> /dev/null
  # 127 means command not found, need install
  if [ $? -eq 127 ]; then
    cd /opt
    sudo wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
    sudo tar -C /usr/local/etc/ -zxf go1.2*
    sudo ln -s /usr/local/etc/go/bin/* /usr/local/bin/
  else
    echo "- go 1.21 \t ok!"
  fi 
}

# v2.7.18
install_python2() {
  python2 -V 2> /dev/null
  if [ $? -eq 127 ]; then
    cd /opt
    if [ ! -f Python-2.7.18.tgz ]; then
      sudo wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
    fi
    sudo tar zxf Python*
    cd Python-2.7.18
    sudo ./configure --enable-optimizations
    sudo make altinstall
    sudo ln -sfn '/usr/local/bin/python2.7' /usr/bin/python2
    sudo update-alternatives --config python
    cd ..
    cd ~/Desktop
  else
    echo "- python2 \t ok!"
  fi
}

# v23.6+
download_lede() {
  local op=0
  if [ -d lede ]; then
    read -p "lede repo have exist, need download it again?" op
    case $op in 
      Y | y | 1) rm -rf lede 
        git clone --depth 1 -b $tag https://github.com/coolsnowwolf/lede.git;; 
      *)  echo "lede repo have exist."
    esac
  else
    read -p "will clone tag $1? [Y/n] " op
    case $op in 
      Y | y | 1) 
        git clone --depth 1 -b $tag https://github.com/coolsnowwolf/lede.git;; 
      *)  echo "lede repo have not download."
    esac
  fi
}

# add new lib in openwrt (insert link in the first row)
update_lede() {
  local op=0
  local content="libqt"
  # qt env
  read -p "add qt5? [Y/n] " op
  case $op in
    Y | y | 1) content=`head --lines=1 feeds.conf.* | awk '{print $2}'`
    # 在首行插入 libqt 的连接
      if [ $content == 'libqt' ]; then
        echo "libqt ok"
      else
        sed -i '1 i src-git libqt https://github.com/qianlue123/qt5-openwrt.git' feeds.conf.default
      fi;;
    *)
  esac

  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

# ----- -----  main()  ----- -----

init_tools

echo "- env --- start --- -"
install_git   # first of all
install_gnu   # gcc g++
install_go
install_cmake
install_python2

# python3 relate
sudo apt install -y python3-distutils python-setuptools
sudo apt install -y python-dev python3-dev  # need find <Python.h>
echo "- env --- setok --- -"

op=0
read -p "install lede? [Y/n] " op
case $op in 
  Y | y | 1) ;;
  *) echo "lede not installed!"; exit
esac

# step 1 select special version
tag="20230609"
op=1
read -p  "which version?
  [1] 20230609	  [2] 20221001  [3] 20211107
select (default $tag) > " op
case $op in 
  3) tag="20211107";;
  2) tag="20221001";;
  *) tag="20230609"
esac

# step 2 download_lede 20230609
download_lede $tag

cd lede
# step 3 update packages
update_lede

# step 4 config it with a UI menu
make menuconfig

# step 5 download them and make
make download -j1

op=0
read -p "start make -jx? [Y/n] " op 
case $op in
  # must to set up thread (-j1), otherwise this script will stuck.
  Y | y | 1) make -j1 V=s;;
  2) make -j2;;
  *) echo "config ok, you can make now!"
esac

cd ..
# step last, check
numbers_pkg=`ls lede/dl/ | wc -l`
# after build, total 173 packages will show up in this dl directory
if [ $numbers_pkg -ge 173 ]; then echo "build ok!"
else
  echo "build failure, pkgs in dl/: $numbers_pkg"
fi

tree -C -sh -L 2 lede/bin/targets/x86
