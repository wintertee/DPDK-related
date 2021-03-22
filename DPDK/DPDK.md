安装pkt-config：
```
apt install pkg-config
```

安装meson和ninja：
```
pip3 install meson ninja
```
安装dpdk：
```
cd dpdk
meson -Dexamples=all -Denable_kmods=true build
cd build
ninja
ninja install
ldconfig
```

检查pkt-config已成功配置：
```
pkg-config --modversion libdpdk
```