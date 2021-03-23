# 安装DPDK

从f-stack中安装：

```shell
wget https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz
tar xzf v1.21.tar.gz
rm v1.21.tar.gz
```

安装pkt-config：

```shell
sudo apt install -y pkg-config python3-pip
```

安装meson和ninja：

```shell
pip3 install meson ninja
echo "export PATH=$PATH:~/.local/bin" >> ~/.bashrc
echo "alias sudo='sudo env PATH=$PATH'" >> ~/.bashrc
source ~/.bashrc
```

安装dpdk：

```shell
cd dpdk
meson -Dexamples=all -Denable_kmods=true build

cd build
ninja
sudo ninja install
sudo ldconfig
```

输出log参见

[meson build](DPDK/meson-build.log)

[ninja install](DPDK/ninja-install.log)

检查pkt-config已成功配置：

```shell
pkg-config --modversion libdpdk
```
