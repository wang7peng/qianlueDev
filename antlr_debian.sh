#!/bin/bash
set -u

# ----- ----- ----- ----- ----- -----
#  platform: debian12

ver='4.13.1'
# ----- ----- -----

#
install_java() {
  local verCur=$(java --version | head -n 1 | awk '{print $2}')

  # default v8
  local verMax=$(echo $verCur | cut -d'.' -f1)
  if [ $verMax -gt 10 ]; then return 0
  fi

  local pkg=jdk-$1_linux-x64_bin.deb
  sudo wget --directory-prefix='/opt' -nc \
    https://download.oracle.com/java/$1/latest/$pkg
  sudo apt install -y /opt/$pkg
}

##### ##### ##### ##### #####
cd /usr/local/lib

install_java '22'

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

