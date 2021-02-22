## 安装f-stack和DPDK：

下载最新的 [f-stack release版本](https://github.com/F-Stack/f-stack/releases)并解压

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

## 开启IOMMU, Hugepage和isolcpu

修改 /etc/default/grub 文件，添加

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash default_hugepagesz=1G hugepagesz=1G hugepages=2 iommu=pt intel_iommu=on isolcpus=4-7"
```
更新GRUB：
```
sudo update-grub
```

挂载Hugepage：
```
mkdir -p /mnt/huge
mount -t hugetlbfs nodev /mnt/huge
```

## 运行testpmd测试dpdk

将电脑的两个网卡之间连接。在虚拟机中，可以添加两个host-only的网卡，并启用混杂模式。（VirtualBox可以直接设置。VMWare需要在vmx文件中添加ethernet%d.noPromisc = "FALSE"）

将两个网卡绑定uio驱动：
```
dev1="ens35"
dev2="ens36"

modprobe uio
insmod dpdk/build/kernel/linux/igb_uio/igb_uio.ko
insmod dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on

python dpdk/usertools/dpdk-devbind.py --status # 查看当前网卡绑定的驱动

ifconfig $dev1 down
ifconfig $dev2 down

python dpdk/usertools/dpdk-devbind.py --bind=igb_uio $dev1
python dpdk/usertools/dpdk-devbind.py --bind=igb_uio $dev2

python dpdk/usertools/dpdk-devbind.py --status # 查看当前网卡绑定的驱动
```

运行testpmd：
```
dpdk/build/app/dpdk-testpmd
```

## 安装f-stack

```
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

## 编译nginx
```
cd app/nginx-1.16.1
bash ./configure --prefix=/usr/local/nginx_fstack --with-ff_module
make
make install
```
## 运行nginx

首先记住网卡的网络信息，并写入f-stack配置文件中
```
dev="ens35"
nginx_dir="/usr/local/nginx_fstack"

myip=`ifconfig $dev | grep inet | grep -v ':' | awk '{print $2}'`
mybroadcast=`ifconfig $dev | grep inet | grep -v ':' | awk '{print $6}'`
mynetmask=`ifconfig $dev | grep inet | grep -v ':' | awk '{print $4}'`
mygateway=`route -n | grep 0.0.0.0 | grep $dev | grep UG | awk -F ' ' '{print $2}'`

sed "s/^addr=.*$/addr=${myip}/" -i -E $nginx_dir/conf/f-stack.conf
sed "s/^netmask=.*$/netmask=${mynetmask}/" -i -E $nginx_dir/conf/f-stack.conf
sed "s/^broadcast=.*$/broadcast=${mybroadcast}/" -i -E $nginx_dir/conf/f-stack.conf
sed "s/^gateway=.*$/gateway=${mygateway}/" -i -E $nginx_dir/conf/f-stack.conf
```
绑定igb_uio：
```
modprobe uio
insmod dpdk/build/kernel/linux/igb_uio/igb_uio.ko
insmod dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on

python dpdk/usertools/dpdk-devbind.py --status # 查看当前网卡绑定的驱动
ifconfig $dev down
python dpdk/usertools/dpdk-devbind.py --bind=igb_uio $dev

```
运行和测试nginx:
```
$nginx_dir/sbin/nginx
ps -ef | grep nginx
curl -v $myip
$nginx_dir/sbin/nginx -s stop
```
