#!/bin/bash

set -u

# ----- ----- version ----- -----
qtcreator="12.0.2"
# ----- ----- --- --- ----- -----

# download run file to /opt
download_run() {
  local pkg=qt-creator-opensource-linux-x86_64-$qtcreator.run # 200M
  local verM=${qtcreator%.*} # 12.0
  local url=https://download.qt.io/official_releases/qtcreator/$verM/$qtcreator/$pkg

  if [ ! -f /opt/$pkg ]; then
    sudo wget --directory-prefix='/opt' --no-verbose $url
  fi

  sudo chmod +777 /opt/$pkg
}

# run .run need
sudo apt install -y libxcb-xinerama0-dev
# restart from lnk need
sudo apt install -y libxcb-cursor0
# use cmd ggsetting
sudo apt install -y libglib2.0-bin
# it can find env of cmake when compile 
sudo apt install -y libgl-dev

addlogo2favorite() {
  local qtdesktop="org.qt-project.qtcreator.desktop"
  local likelist=`gsettings get org.gnome.shell favorite-apps`
  echo $likelist
  likelist=$(echo $likelist | sed -e "s/]/, '$qtdesktop']/")
  gsettings set org.gnome.shell favorite-apps "$likelist"
}

download_run

# sudo will install in /opt
cd /opt
op=0
read -p "qt will install in root? (default not)" op
case $op in 
  Y | y | 1) sudo ./$pkgRun;;
  *) ./$pkgRun
esac

if [ $? -eq 0 ]; then
  echo "export PATH=\$PATH:/opt/qtcreator-$ver/bin" >> ~/.bashrc
  source ~/.bashrc
fi

# ubuntu20+
addlogo2favorite

