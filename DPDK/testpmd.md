# 测试testpmd

参考：<https://doc.dpdk.org/guides-20.05/linux_gsg/linux_drivers.html>

将电脑的两个网卡之间连接。

注意：

- 在虚拟机中，可以添加两个host-only的网卡，并启用混杂模式。（VirtualBox可以直接设置。VMWare需要在vmx文件中添加ethernet%d.noPromisc = "FALSE"）
- 如果[开启了IOMMU并配置了内核启动参数](../prerequisite/kernel%20parameters.md)或在VMWare中开启了[vIOMMU](https://docs.vmware.com/cn/VMware-Workstation-Pro/16.0/com.vmware.ws.using.doc/GUID-3140DF1F-A105-4EED-B9E8-D99B3D3F0447.html)后可通过`modprobe vfio-pci`挂载`vfio驱动`。这会在虚拟机中带来更好的安全性。<https://doc.dpdk.org/guides-19.11/linux_gsg/linux_drivers.html?highlight=vfio>

将两个网卡绑定uio驱动：

```shell
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
# python dpdk/usertools/dpdk-devbind.py --bind=vfio-pci $dev2

python dpdk/usertools/dpdk-devbind.py --status # 查看当前网卡绑定的驱动
```

运行testpmd：

```shell
dpdk/build/app/dpdk-testpmd
```
