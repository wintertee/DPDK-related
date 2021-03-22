文档：https://www.kernel.org/doc/html/v4.15/admin-guide/kernel-parameters.html

修改 /etc/default/grub 文件，添加

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash default_hugepagesz=1G hugepagesz=1G hugepages=12 iommu=pt intel_iommu=on isolcpus=0-6"
```
更新GRUB：
```
sudo update-grub
```

挂载Hugepage：https://doc.dpdk.org/guides-19.11/linux_gsg/sys_reqs.html
```
sudo mkdir -p /mnt/huge
# mount -t hugetlbfs pagesize=1GB /mnt/huge # 临时挂载
sudo sh -c "echo 'nodev /mnt/huge hugetlbfs pagesize=1GB 0 0' >> /etc/fstab" # 永久挂载
```

检查Hugepage:
```
grep Huge /proc/meminfo
```

## 关闭Swap

为k8s做准备

```
sudo swapoff -v /swapfile
```

在`/etc/fstab`中注释掉swap

```
sudo rm /swapfile
```

