# 安装f-stack

```shell

apt-get install libpcap-dev

# Compile F-Stack
export FF_PATH=/data/f-stack
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig
cd /data/f-stack/lib/
make

# Install F-STACK
# libfstack.a will be installed to /usr/local/lib
# ff_*.h will be installed to /usr/local/include
# start.sh will be installed to /usr/local/bin/ff_start
# config.ini will be installed to /etc/f-stack.conf
make install
```

测试：

```shell

cd f-stack/example
make
```

如果出现 `undefined reference` 可在 `Makefile` 文件中添加 `-lpcap`
