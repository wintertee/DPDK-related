# 测试helloworld

## 配置config.ini

``` shell
nb_vdev=2
```

``` shell
[port0]
addr=192.168.1.2
netmask=255.255.225.0
broadcast=192.168.1.255
gateway=192.168.1.1
[port1]
addr=192.168.1.3
netmask=255.255.225.0
broadcast=192.168.1.255
gateway=192.168.1.1
```

``` shell
[vdev0]
##iface=/usr/local/var/run/openvswitch/vhost-user0
path=/var/run/openvswitch/vhost-user1
queues=1
queue_size=256
mac=00:00:00:00:00:01
#cq=0
[vdev1]
path=/var/run/openvswitch/vhost-user2
queues=1
queue_size=256
mac=00:00:00:00:00:02
```

## 运行helloworld

``` shell
example/helloworld --conf=config.ini
```

## 错误排查

``` shell
f-stack -c1 -n1 --proc-type=auto --vdev=virtio_user0,path=/var/run/openvswitch/vhost-user1,queues=1,queue_size=256,mac=00:00:00:00:00:01 --no-pci --file-prefix=container EAL: Probing VFIO support...
EAL: VFIO support initialized
lcore: 0, port: 0, queue: 0
create mbuf pool on socket 0
create ring:dispatch_ring_p0_q0 success, 2047 ring entries are now free!
Port 0 MAC: 00 00 00 00 00 01
Port 0 modified RSS hash function based on hardware support,requested:0x3ffffc configured:0
virtio_dev_configure(): Unsupported Rx multi queue mode 1
Port0 dev_configure = -22
EAL: Error - exiting with code: 1
  Cause: init_port_start failed
 ```

参考:

[F-Stack/f-stack#489](https://github.com/F-Stack/f-stack/issues/489)

[mtcp-stack/mtcp#282](https://github.com/mtcp-stack/mtcp/issues/282)

[net/virtio: reject unsupported Rx multi queue modes](https://patches.dpdk.org/project/dpdk/patch/1569944672-24754-3-git-send-email-arybchenko@solarflare.com/)

临时解决方法：
注释掉[dpdk/drivers/net/virtio/virtio_ethdev.c#L2080](https://github.com/F-Stack/f-stack/blob/2df8fe233511da315136e8a64f0f63428b5cab73/dpdk/drivers/net/virtio/virtio_ethdev.c#L2080)
