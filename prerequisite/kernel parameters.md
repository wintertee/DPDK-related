# 内核配置

文档：https://www.kernel.org/doc/html/v4.15/admin-guide/kernel-parameters.html

修改 /etc/default/grub 文件，添加

```shell
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash default_hugepagesz=1G hugepagesz=1G hugepages=12 iommu=pt intel_iommu=on isolcpus=0-6"
```

更新GRUB：

```shell
sudo update-grub
```

挂载Hugepage：http://doc.dpdk.org/guides/linux_gsg/sys_reqs.html?highlight=hugepages

```shell
sudo mkdir -p /mnt/huge
# mount -t hugetlbfs pagesize=1GB /mnt/huge # 临时挂载
sudo sh -c "echo 'nodev /mnt/huge hugetlbfs pagesize=1GB 0 0' >> /etc/fstab" # 永久挂载
```

检查Hugepage:

```shell
grep Huge /proc/meminfo
```

## 关闭Swap

为k8s做准备

```shell
sudo swapoff -v /swapfile
```

在 `/etc/fstab` 中注释掉swap

```shell
sudo rm /swapfile
```
