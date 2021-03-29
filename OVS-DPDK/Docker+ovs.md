# 在Docker中使用OVS网桥

创建无网络容器：

``` shell
sudo docker run --net=none --privileged=true -it ovs-docker bash
```

为容器添加网卡：

``` shell
sudo ~/openvswitch-2.13.3/utilities/ovs-docker add-port br0 eth0 <container ID>  --ipaddress=192.168.0.2/24
```

需要注意的是，Docker只能连接到`datapath_type=system`的内核态网桥。如果连接到`netdev`的用户态网桥，Docker会缺少TCP/IP协议栈。

此外，OVS不支持`system`和`netdev`两种网桥的连接(patch)。

参考：

<https://docs.openvswitch.org/en/latest/intro/install/userspace/>

<https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html-single/ovs-dpdk_end_to_end_troubleshooting_guide/index#confirming_compute_node_ovs_configuration>
