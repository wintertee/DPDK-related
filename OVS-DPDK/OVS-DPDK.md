# OVS-DPDK

## 安装OVS-dpdk

参考 https://docs.openvswitch.org/en/latest/intro/install/dpdk/ https://blog.csdn.net/me_blue/article/details/78589592

```shell
./configure --with-dpdk=/usr/local/f-stack/dpdk/build CFLAGS="-Ofast -msse4.2 -mpopcnt -mavx"
make
make install
```

## 运行OVS-dpdk

参考：https://blog.csdn.net/cloudvtech/article/details/80492234

```shell
export PATH=$PATH:/usr/local/share/openvswitch/scripts
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock

ovsdb-tool create /usr/local/etc/openvswitch/conf.db /usr/local/share/openvswitch/vswitch.ovsschema

# ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
#                      --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
#                      --private-key=db:Open_vSwitch,SSL,private_key \
#                      --certificate=db:Open_vSwitch,SSL,certificate \
#                      --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert \
#                      --pidfile --detach
# ovs-vsctl --no-wait init
# ovs-vswitchd --pidfile --detach

ovs-ctl --db-sock="$DB_SOCK" start

ovs-vsctl --no-wait init
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=0x4
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x4
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem=1024

# https://docs.openvswitch.org/en/latest/topics/dpdk/bridge/
ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
ovs-vsctl show

# 添加四个vhost-user1-4连接2-3连接
# https://docs.openvswitch.org/en/latest/topics/dpdk/vhost-user/#vhost-user-vs-vhost-user-client

ovs-vsctl add-port br0 vhost-user1 -- set Interface vhost-user1 type=dpdkvhostuser
ovs-vsctl add-port br0 vhost-user2 -- set Interface vhost-user2 type=dpdkvhostuser
ovs-vsctl add-port br0 vhost-user3 -- set Interface vhost-user3 type=dpdkvhostuser
ovs-vsctl add-port br0 vhost-user4 -- set Interface vhost-user4 type=dpdkvhostuser
ovs-vsctl show

ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,idle_timeout=0,action=output:3
ovs-ofctl add-flow br0 in_port=3,dl_type=0x800,idle_timeout=0,action=output:2
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,idle_timeout=0,action=output:4
ovs-ofctl add-flow br0 in_port=4,dl_type=0x800,idle_timeout=0,action=output:1

```

检查配置：

```shell
ovs-vsctl show 
ovs-ofctl show br0
ovs-ofctl dump-flows br0
ovs-ofctl dump-ports br0
```

## 关闭ovs

```shell
ovs-appctl -t ovs-vswitchd exit
ovs-appctl -t ovsdb-server exit
```
