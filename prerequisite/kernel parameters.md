文档：https://www.kernel.org/doc/html/v4.15/admin-guide/kernel-parameters.html

修改 /etc/default/grub 文件，添加

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash default_hugepagesz=1G hugepagesz=1G hugepages=6 iommu=pt intel_iommu=on isolcpus=0-6"
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
