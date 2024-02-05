# QianlueDev

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-E95420?style=social&logo=ubuntu&logoColor=E95420)

## 使用

除了 `gcc` 和 `python3` 手动安装，其他工具都是脚本自动安装。

```bash
sudo apt install -y gcc g++  # c
sudo apt install -y python3-distutils
sudo apt install -y python3-setuptools
```


## 脚本介绍

【openwrt_build.sh】从原网安装 openwrt（不是从个人源安装）。

经测试，在 Ubuntu16上直接 clone 它的 `23.05` 分支不能编译，提示要求 gcc `v6` 以上，python `v3.6` 以上。

> 公司板子配置
>
> - Arch: MIPS
>
> - CPU: MediaTek MT7621AT
> - DRAM: 128 M

【pjsip_install.sh】这个库安装完成后，运行自己项目时，还要先安装两个东西

```bash
sudo apt install -y libssl-dev  # libssl.so
sudo apt install -y libgl-dev   # -lGL
```



## 脚本写法 Tips

- 想把函数输出给变量，尽量不用 return $ 这种写法, 他返回的值只能是 0-255 的整数（实质是状态码），在最后一行打 echo 更好。

- 语句执行后的状态码 `$?` ，命令不存在 `=127` ，命令参数不存在 `=2`

- 查看版本信息，有的默认显示一大堆的话，可以用 `head -n` 提取某一行

- `sudo echo "xxx" >> /x/file` 只在 root 用户或者 `sudo bash name.sh` 有用，不加 `sudo` 直接按普通用户 `bash name.sh` 运行就不行，要么 `sh -c` 将整体当作一个字符串命令执行；要么改成 `echo "xxx" | sudo tee -a /x/file`

- TODO
