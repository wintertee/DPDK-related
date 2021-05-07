# 安装DPDK

从f-stack中安装：

```shell
wget https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz
tar xzf v1.21.tar.gz
rm v1.21.tar.gz
```

或从源安装：

```shell
wget https://fast.dpdk.org/rel/dpdk-20.11.1.tar.xz
tar xf dpdk-20.11.1.tar.xz
rm dpdk-20.11.1.tar.xz
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

[meson build](meson-build.log)

[ninja install](ninja-install.log)

检查pkt-config已成功配置：

```shell
pkg-config --modversion libdpdk
```

> v20.02版本以后，DPDK就默认关闭igb_uio模块。若构建它，需要配置文件选项CONFIG_RTE_EAL_IGB_UIO设置为enabled。并且官方已计划将其移到其他项目；配置文件dpdk/config/common_base中开启该配置CONFIG_RTE_EAL_IGB_UIO=y，注意这个文件是全局配置。如果仅修改局部的编译，可以在编译时各自文件夹dpdk/x86_64-native-linux-gcc/.config文件中对应修改该参数。（调试DPDK可开启参数CONF_RTE_LIBRTE_CRYPTODEV_DEBUG=y
