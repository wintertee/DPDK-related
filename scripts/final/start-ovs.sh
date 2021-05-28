export PATH=$PATH:/usr/local/share/openvswitch/scripts
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock

ovsdb-tool create /usr/local/etc/openvswitch/conf.db /usr/local/share/openvswitch/vswitch.ovsschema

ovs-ctl --db-sock="$DB_SOCK" start

ovs-vsctl --no-wait init
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=0x4
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x4
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem=1024

ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev

ovs-vsctl add-port br0 vhost-user1 -- set Interface vhost-user1 type=dpdkvhostuser
ovs-vsctl add-port br0 dpdk-p0     -- set Interface dpdk-p0     type=dpdk options:dpdk-devargs=0000:01:00.0

ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=1,dl_type=0x800,idle_timeout=0,action=output:2
ovs-ofctl add-flow br0 in_port=2,dl_type=0x800,idle_timeout=0,action=output:1
