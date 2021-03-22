## 编译nginx
```
apt-get install libpcre3 libpcre3-dev  
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
