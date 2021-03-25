# 测试helloworld

## 配置config.ini

```shell
nb_vdev=2
```

```shell
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

```shell
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

```shell
example/helloworld --conf=config.ini
```
