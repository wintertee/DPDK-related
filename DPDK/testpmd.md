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
