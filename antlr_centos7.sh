#!/bin/bash
set -u

# ----- ----- ----- ----- ----- -----
#  platform: centos7 (with base tools)

ver='4.13.1'
# ----- ----- -----

# default java in CentOS7 not enough
#
install_java() {
  local verCur=$(java --version | head -n 1 | awk '{print $2}')

  # default v8
  local verMax=$(echo $verCur | cut -d'.' -f1)
  if [ $verMax -gt 10 ]; then return 0
  fi

  local pkg='jdk-17_linux-x64_bin.rpm'
  sudo wget --directory-prefix='/opt' -nc \
    https://download.oracle.com/java/17/latest/$pkg
  sudo yum install -y /opt/$pkg
}

install_java

##### ##### ##### ##### #####

cd /usr/local/lib
pkg=antlr-$ver-complete.jar # 2.1M

if [ ! -f $pkg ]; then
  sudo curl -O https://www.antlr.org/download/$pkg
fi

echo "alias antlr4='java -jar /usr/local/lib/${pkg}'" | sudo tee -a ~/.bashrc
echo "alias grun='java org.antlr.v4.runtime.misc.TestRig'" | sudo tee -a ~/.bashrc
source ~/.bashrc

# test
java -jar /usr/local/lib/$pkg
antlr4

