# qianlueDev

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-E95420?style=social&logo=ubuntu&logoColor=E95420)
![Debian](https://img.shields.io/badge/Debian-12.5+-E95420?style=social&logo=debian&logoColor=red)

## Usage

除了 `gcc` 和 `python3` 手动安装，其他工具都是脚本自动安装。

```bash
sudo apt install -y gcc g++  # c
sudo apt install -y python3-distutils
sudo apt install -y python3-setuptools
```


## Tips for Write

- 想把函数输出给变量，尽量不用 return $ 这种写法, 他返回的值只能是 0-255 的整数（实质是状态码），在最后一行打 echo 更好。

- 语句执行后的状态码 `$?` ，命令不存在 `=127` (命令前带 `sudo` 的话还是 `=1` )，命令参数不存在 `=2`

- 查看版本信息，有的默认显示一大堆的话，可以用 `head -n` 提取某一行

- `sudo echo "xxx" >> /x/file` 只在 root 用户或者 `sudo bash name.sh` 有用，不加 `sudo` 直接按普通用户 `bash name.sh` 运行就不行，要么 `sh -c` 将整体当作一个字符串命令执行；要么改成 `echo "xxx" | sudo tee -a /x/file`

- `mysql -Ne "xxx;"` 去掉显示表格式的头行，必须先 `-N` 再 `-e`

- TODO
