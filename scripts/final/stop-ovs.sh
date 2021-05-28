ovs-vsctl --if-exists del-br br0
ovs-appctl -t ovs-vswitchd exit
ovs-appctl -t ovsdb-server exit