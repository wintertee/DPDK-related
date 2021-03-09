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

检查pkt-config已成功配置：
```
pkg-config --modversion libdpdk
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

挂载Hugepage：http://doc.dpdk.org/guides/linux_gsg/sys_reqs.html?highlight=hugepages
```
mkdir -p /mnt/huge
# mount -t hugetlbfs pagesize=1GB /mnt/huge # 临时挂载
echo "nodev /mnt/huge hugetlbfs pagesize=1GB 0 0" >> /etc/fstab # 永久挂载
```

检查Hugepage:
```
grep Huge /proc/meminfo
```

## 运行testpmd测试dpdk

参考：https://doc.dpdk.org/guides-20.05/linux_gsg/linux_drivers.html

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

参考：https://ytlm.github.io/2018/05/f-stack%E5%88%9D%E6%8E%A2/

首先记住网卡的网络信息，并写入f-stack配置文件中
```
dev1="ens35"
dev2="ens36"
nginx_dir="/usr/local/nginx_fstack"

myip=`ifconfig $dev1 | grep inet | grep -v ':' | awk '{print $2}'`
mybroadcast=`ifconfig $dev1 | grep inet | grep -v ':' | awk '{print $6}'`
mynetmask=`ifconfig $dev1 | grep inet | grep -v ':' | awk '{print $4}'`
# mygateway=`route -n | grep 0.0.0.0 | grep $dev | grep UG | awk -F ' ' '{print $2}'`
mygateway=`ifconfig $dev2 | grep inet | grep -v ':' | awk '{print $2}'`
# dev1和dev2都是host-only网卡，两个网卡相连，所以把dev2的ip作为dev1的网关。稍后通过dev2访问运行在dev1上的nginx

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
ifconfig $dev1 down
python dpdk/usertools/dpdk-devbind.py --bind=igb_uio $dev1

```
运行和测试nginx:
```
$nginx_dir/sbin/nginx
ps -ef | grep nginx
curl -v $myip
$nginx_dir/sbin/nginx -s stop
```

## 下载和安装pktgen

下载pktgen-21.02.0，解压到f-stack目录下。
```
cd pktgen-21.02.0
meson build
cd build
ninja
ninja install
```

## 安装OVS-dpdk
参考 https://docs.openvswitch.org/en/latest/intro/install/dpdk/ https://blog.csdn.net/me_blue/article/details/78589592
```
./configure --with-dpdk=/usr/local/f-stack/dpdk/build CFLAGS="-Ofast -msse4.2 -mpopcnt -mavx"
make
make install
```

## 运行OVS-dpdk
参考：https://blog.csdn.net/cloudvtech/article/details/80492234
```
rm -rf /usr/local/etc/openvswitch/conf.db #需要删除吗？不确定
export PATH=$PATH:/usr/local/share/openvswitch/scripts
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock

ovs-ctl --db-sock="$DB_SOCK" start

ovs-vsctl --no-wait init
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=0x2
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x4
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem=1024
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock

# https://docs.openvswitch.org/en/latest/topics/dpdk/bridge/
ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
ovs-vsctl show

# 添加四个vhost-user，1-4连接，2-3连接
# https://docs.openvswitch.org/en/latest/topics/dpdk/vhost-user/#vhost-user-vs-vhost-user-client

ovs-vsctl add-port br0 vhost-user0 -- set Interface vhost-user0 type=dpdkvhostuser
ovs-vsctl add-port br0 vhost-user1 -- set Interface vhost-user1 type=dpdkvhostuser
ovs-vsctl add-port br0 vhost-user2 -- set Interface vhost-user2 type=dpdkvhostuser
ovs-vsctl add-port br0 vhost-user3 -- set Interface vhost-user3 type=dpdkvhostuser
ovs-vsctl show

ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,idle_timeout=0,action=output:3
ovs-ofctl add-flow br0 in_port=3,dl_type=0x800,idle_timeout=0,action=output:2
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,idle_timeout=0,action=output:4
ovs-ofctl add-flow br0 in_port=4,dl_type=0x800,idle_timeout=0,action=output:1

```

检查配置：
```
ovs-vsctl show 
ovs-ofctl show br0
ovs-ofctl dump-flows br0
ovs-ofctl dump-ports br0
```

## 创建容器
创建Dockerfile：
```
FROM ubuntu:18.04
WORKDIR /usr/local/f-stack
COPY . /usr/local/f-stack
RUN apt update && apt install -y libnuma-dev libssl-dev vim libpcap-dev
ENV PATH "$PATH:/usr/local/f-stack/dpdk/build/app/"
```

创建镜像：
```
docker build -t f-stack .
```

运行容器：
```
docker run -ti --privileged -v /mnt/huge:/mnt/huge -v /usr/local/var/run/openvswitch:/var/run/openvswitch -v /usr/local/lib/x86_64-linux-gnu:/usr/local/lib/x86_64-linux-gnu f-stack
```

```
docker exec -it <ID> bash
```

## 测试ovs-dpdk和docker
参考：https://blog.csdn.net/me_blue/article/details/78589592
![示意图](http://ww1.sinaimg.cn/large/411271bbly1flkxo8h5zoj20ot0fzwhc.jpg)

先在第一个容器中运行pktgen：
```
pktgen-21.02.0/build/app/pktgen -c 0x19 --master-lcore 3 -n 1 --socket-mem 1024 --file-prefix pktgen --no-pci  \
--vdev 'net_virtio_user0,mac=00:00:00:00:00:05,path=/var/run/openvswitch/vhost-user0' \
--vdev 'net_virtio_user1,mac=00:00:00:00:00:01,path=/var/run/openvswitch/vhost-user1' \
-- -T -P -m "0.0,4.1"
```
