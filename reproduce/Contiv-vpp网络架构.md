# Contiv/VPP Network Operation

This document describes the network operation of the Contiv/VPP k8s network plugin. It elaborates the operation and config options of the Contiv IPAM, as well as details on how the VPP gets programmed by Contiv/VPP control plane.

本文件描述了Contiv/VPP k8s网络插件的网络操作。它阐述了Contiv IPAM的操作和配置选项，以及VPP如何被Contiv/VPP控制平面编程的细节。

The following picture shows 2-node k8s deployment of Contiv/VPP, with a VXLAN tunnel established between the nodes to forward inter-node POD traffic. The IPAM options are depicted on the Node 1, whereas the VPP programming is depicted on the Node 2.

下图显示了Contiv/VPP的2个节点k8s部署，节点之间建立了VXLAN隧道来转发节点间的POD流量。IPAM选项被描述在节点1上，而VPP编程被描述在节点2上。

[![Contiv/VPP Architecture](https://github.com/contiv/vpp/raw/master/docs/img/contiv-networking.png)](https://github.com/contiv/vpp/blob/master/docs/img/contiv-networking.svg)

## Contiv/VPP IPAM (IP Address Management)

IPAM in Contiv/VPP is based on the concept of **Node ID**. The Node ID is a number that uniquely identifies a node in the k8s cluster. The first node is assigned the ID of 1, the second node 2, etc. If a node leaves the cluster, its ID is released back to the pool and will be re-used by the next node.

Contiv/VPP的IPAM是基于节点ID的概念。节点ID是一个数字，用于唯一识别k8s集群中的一个节点。第一个节点的ID是1，第二个节点是2，等等。如果一个节点离开集群，它的ID会被释放回池子里，并将被下一个节点重新使用。

The Node ID is used to calculate per-node IP subnets for PODs and other internal subnets that need to be unique on each node. Apart from the Node ID, the input for IPAM calculations is a set of config knobs, which can be specified in the `IPAMConfig` section of the [Contiv/VPP deployment YAML](https://github.com/contiv/vpp/blob/master/k8s/contiv-vpp.yaml):

节点ID用于计算POD的每个节点IP子网和其他需要在每个节点上唯一的内部子网。除了节点ID，IPAM计算的输入是一组配置，可以在Contiv/VPP部署YAML的 "IPAMConfig "部分指定":

* **PodSubnetCIDR** (default `10.1.0.0/16`): each pod gets an IP address assigned from this range. The size of this range (default `/16`) dictates upper limit of POD count for the entire k8s cluster (default 65536 PODs).
* **PodSubnetCIDR** (默认为`10.1.0.0/16`): 每个pod从这个范围得到一个IP地址。这个范围的大小（默认为`/16`）决定了整个k8s集群的POD数量的上限（默认为65536个POD）。
* **PodSubnetOneNodePrefixLen** (default `24`): per-node dedicated podSubnet range. From the allocatable range defined in `PodSubnetCIDR`, this value will dictate the allocation for each node. With the default value (`24`) this indicates that each node has a `/24` slice of the `PodSubnetCIDR`. The Node ID is used to address the node. In case of `PodSubnetCIDR = 10.1.0.0/16`,  `PodSubnetOneNodePrefixLen = 24` and `NodeID = 5`, the resulting POD subnet for the node would be `10.1.5.0/24`.
* **PodSubnetOneNodePrefixLen** (默认为`24`): 每个节点专用的podSubnet范围。从`PodSubnetCIDR`中定义的可分配范围，这个值将决定每个节点的分配。默认值(`24`)表示每个节点拥有`PodSubnetCIDR`的`/24`分片。节点ID是用来对节点进行寻址的。如果`PodSubnetCIDR = 10.1.0.0/16`，`PodSubnetOneNodePrefixLen = 24`和`NodeID = 5`，则该节点的POD子网将是`10.1.5.0/24`。
* **VPPHostSubnetCIDR** (default `172.30.0.0/16`): used for addressing the interconnect of the VPP with the Linux network stack within the same node. Since this subnet needs to be unique on each node, the Node ID is used to determine the actual subnet used on the node with the combination of `VPPHostSubnetOneNodePrefixLen`, similarly as for the `PodSubnetCIDR` and `PodSubnetOneNodePrefixLen`.
* **VPPHostSubnetCIDR**（默认为`172.30.0.0/16`）：用于解决VPP与同一节点内的Linux网络栈的互连。由于该子网在每个节点上需要是唯一的，节点ID用于确定节点上实际使用的子网与`VPPHostSubnetOneNodePrefixLen`的组合，类似于`PodSubnetCIDR`和`PodSubnetOneNodePrefixLen`。
* **VPPHostSubnetOneNodePrefixLen** (default `24`): used to calculate the subnet for addressing the interconnect of VPP with the Linux network stack within the same node. With `VPPHostSubnetCIDR = 172.30.0.0/16`,  `VPPHostSubnetOneNodePrefixLen = 24` and `NodeID = 5` the resulting subnet for the node would be `172.30.5.0/24`.
* **VPPHostSubnetOneNodePrefixLen**（默认为`24`）：用于计算子网，以解决VPP与同一节点内的Linux网络栈的互连。在`VPPHostSubnetCIDR = 172.30.0.0/16`，`VPPHostSubnetOneNodePrefixLen = 24`和`NodeID = 5`的情况下，该节点的子网将是`172.30.5.0/24`。
* **NodeInterconnectCIDR** (default `192.168.16.0/24`): range for the addresses assigned to the data plane interfaces managed by VPP. Unless DHCP is used (`NodeInterconnectDHCP = True`), Contiv/VPP control plane automatically assigns an IP address from this range to the DPDK-managed ethernet interface bound to the VPP on each node. The actual IP address will be calculated from the Node ID, e.g. with `NodeInterconnectCIDR = 192.168.16.0/24` and `NodeID = 5` the resulting IP address assigned to ethernet interface on VPP will be `192.168.16.5`.
* **NodeInterconnectCIDR**（默认为192.168.16.0/24）：分配给VPP管理的数据平面接口的地址范围。除非使用DHCP（`NodeInterconnectDHCP = True`），否则Contiv/VPP控制平面会从这个范围内自动分配一个IP地址给每个节点上与VPP绑定的DPDK管理的以太网接口。实际的IP地址将从节点ID计算出来，例如，在`NodeInterconnectCIDR = 192.168.16.0/24`和`NodeID = 5`的情况下，分配给VPP的以太网接口的IP地址将是`192.168.16.5`。
* **NodeInterconnectDHCP** (default `False`): instead of assigning the IPs for the data plane interfaces managed by VPP from the `NodeInterconnectCIDR` by Contiv/VPP control plane, use DHCP that must be running in the network where the data plane interface is connected to. In case that `NodeInterconnectDHCP = True`,  `NodeInterconnectCIDR` is ignored.
* **NodeInterconnectDHCP** (默认为`False')：不通过Contiv/VPP控制平面从`NodeInterconnectCIDR'为VPP管理的数据平面接口分配IP，而是使用必须在数据平面接口所连接的网络中运行的DHCP。如果`NodeInterconnectDHCP = True`，`NodeInterconnectCIDR`将被忽略。
* **VxlanCIDR** (default `192.168.30.0/24`): in order to provide inter-node POD to POD connectivity via any underlay network (not necessarily a L2 network), Contiv/VPP sets up VXLAN tunnel overlay between each 2 nodes within the cluster. For this purpose, each node needs its unique IP address of the VXLAN BVI interface. This IP address is automatically calculated from the Node ID, e.g. with `VxlanCIDR = 192.168.30.0/24` and `NodeID = 5` the resulting IP address assigned to VXLAN BVI interface will be `192.168.30.5`.
* **VxlanCIDR**（默认为192.168.30.0/24）：为了通过任何底层网络（不一定是L2网络）提供节点间的POD到POD的连接，Contiv/VPP在集群内每2个节点之间设置了VXLAN隧道叠加。为此，每个节点都需要其独特的VXLAN BVI接口的IP地址。这个IP地址是由节点ID自动计算出来的，例如：`VxlanCIDR = 192.168.30.0/24`和`NodeID = 5`，分配给VXLAN BVI接口的IP地址将是`192.168.30.5`。

## VPP Programming

This section describes how Contiv/VPP control plane programs the VPP based on the events it receives from k8s. It is not necessarily needed to understand this section for basic operation of Contiv/VPP, but it can be very useful for debugging purposes.

本节描述了Contiv/VPP控制平面如何根据它从k8s收到的事件对VPP进行编程。对于Contiv/VPP的基本操作来说，不一定需要了解这一节，但对于调试来说是非常有用的。

Contiv/VPP currently uses two VRFs - one to connect PODs on all nodes and the other to connect host network stack and DPDK-managed dataplane interface. Routing between them enforces inter-node traffic to be sent in VXLAN and allows to access PODs from host network stack. The forwarding among PODs is purely L3-based, even for case of communication between 2 PODs within the same node.

Contiv/VPP目前使用两个VRF--一个用于连接所有节点上的POD，另一个用于连接主机网络栈和DPDK管理的数据平面接口。它们之间的路由强制要求节点间的流量在VXLAN中发送，并允许从主机网络栈访问POD。POD之间的转发纯粹是基于L3的，即使是同一节点内的两个POD之间的通信也是如此。

#### DPDK-managed data interface

In order to allow inter-node communication between PODs on different nodes and between PODs and outside world, Contiv/VPP uses data-plane interfaces bound to VPP using DPDK. Each node should have one "main" VPP interface, which is unbound from the host network stack and bound to VPP. Contiv/VPP control plane automatically configures the interface either via DHCP, or with statically assigned address (see `NodeInterconnectCIDR` and `NodeInterconnectDHCP` yaml settings).

为了允许不同节点上的POD之间以及POD与外界之间进行节点间的通信，Contiv/VPP使用DPDK与VPP绑定的数据平面接口。每个节点都应该有一个 "主 "VPP接口，该接口不与主机网络堆栈绑定，而是与VPP绑定。Contiv/VPP控制平面通过DHCP或静态分配的地址自动配置接口（见 `NodeInterconnectCIDR` 和 `NodeInterconnectDHCP` yaml设置）。

#### PODs on the same node

PODs are connected to VPP using virtio-based TAP interfaces created by VPP, with POD-end of the interface placed into the POD container network namespace. Each POD is assigned an IP address from the `PodSubnetCIDR` . The allocated IP is configured with the prefix length `/32` . Additionally, a static route pointing towards the VPP is configured in the POD network namespace. The prefix length `/32` means that all IP traffic will be forwarded to the default route - VPP. To get rid of unnecessary broadcasts between POD and VPP, a static ARP entry is configured for the gateway IP in the POD namespace, as well as for POD IP on VPP. Both ends of the TAP interface have a static (non-default) MAC address applied.

POD使用VPP创建的基于virtio的TAP接口连接到VPP，接口的POD端被放入POD容器网络命名空间。每个POD从 `PodSubnetCIDR` 中分配一个IP地址。分配的IP被配置为前缀长度 `/32` 。此外，在POD网络命名空间中配置了一个指向VPP的静态路由。前缀长度 `/32` 意味着所有的IP流量将被转发到默认路由 - VPP。为了摆脱POD和VPP之间不必要的广播，在POD命名空间为网关IP配置了一个静态ARP条目，在VPP上也为POD IP配置了静态ARP。TAP接口的两端都有一个静态（非默认）的MAC地址。

#### PODs with hostNetwork=true

PODs with `hostNetwork=true` attribute are not placed into a separate network namespace

* they use the main host Linux network namespace. Therefore, they are not directly connected to the VPP. They rely on the interconnection between the VPP and the host Linux network stack, which is described in the next paragraph. Note that in case that these PODs access some service IP, their network communication will be NATed in Linux (by iptables rules programmed by kube-proxy) as opposed to VPP, which is the case for the PODs connected to VPP directly.

带有 `hostNetwork=true` 属性的POD不会被放入一个单独的网络命名空间中

* 它们使用主要的主机Linux网络命名空间。因此，它们不直接连接到VPP。它们依赖于VPP和主机Linux网络堆栈之间的互连，这将在下一段描述。请注意，如果这些POD访问一些服务IP，它们的网络通信将在Linux中被NAT处理（通过kube-proxy编程的iptables规则），而不是VPP，这就是直接连接到VPP的POD的情况。

#### Linux host network stack

In order to interconnect the Linux host network stack with the VPP (to allow the access to the cluster resources from the host itself, as well as for the PODs with `hostNetwork=true` ), VPP creates a TAP interface between VPP and the main network namespace. It is configured with an IP addresses from the `VPPHostSubnetCIDR` range, with `.1` in the latest octet on the VPP side, and `.2` on the host side. The name of the host interface is `vpp1` . The host has two static routes pointing to VPP configured: a route to the whole `PodSubnetCIDR` to route traffic targeting PODs towards VPP and a route to `ServiceCIDR` (default `10.96.0.0/12` ), to route service IP targeted traffic that has not been translated by kube-proxy for some reason towards VPP. To get rid of unnecessary broadcasts between the main network namespace and VPP, the host also has a static ARP entry configured for the IP of the VPP-end TAP interface.

为了使Linux主机网络堆栈与VPP互连（允许从主机本身访问集群资源，以及为 `hostNetwork=true'的POD访问），VPP在VPP和主网络命名空间之间创建一个TAP接口。它被配置为` VPPHostSubnetCIDR `范围内的IP地址，在VPP一侧的最新八位数中为` .1 `，在主机一侧为` .2 `。主机接口的名称是` vpp1 `。主机配置了两条指向VPP的静态路由：一条是指向整个` PodSubnetCIDR `的路由，将针对POD的流量导向VPP；一条是指向` ServiceCIDR `（默认为` 10.96.0.0/12`）的路由，将因某些原因未被kube-proxy翻译的服务IP目标流量导向VPP。为了摆脱主网络命名空间和VPP之间不必要的广播，主机还为VPP端TAP接口的IP配置了一个静态ARP条目。

#### VXLANs to other nodes

In order to provide inter-node POD to POD connectivity via any underlay network (not necessarily a L2 network), Contiv/VPP sets up a VXLAN tunnel overlay between each 2 nodes within the cluster (full mesh).

为了通过任何底层网络（不一定是L2网络）提供节点间的POD到POD的连接，Contiv/VPP在集群内的每2个节点之间设置了一个VXLAN隧道覆盖（全网）。

All VXLAN tunnels are terminated in one bridge domain on each VPP. The bridge domain has learning and flooding disabled, the l2fib of the bridge domain is filled in with a static entry for each VXLAN tunnel. Each bridge domain has a BVI interface which interconnects the bridge domain with the POD VRF (L3 forwarding). This interface needs an unique IP address, which is assigned from the `VxlanCIDR` as describe above.

所有VXLAN隧道都在每个VPP的一个桥域中终止。桥域禁止学习和泛洪，桥域的l2fib为每个VXLAN隧道填写了一个静态条目。每个桥域都有一个BVI接口，将桥域与POD VRF（L3转发）互连。这个接口需要一个唯一的IP地址，如上所述，这个地址是由 `VxlanCIDR` 分配的。

The POD VRF contains several static routes that point to the BVI IP addresses of other nodes. For each node, it is a route to PODSubnet and VppHostSubnet of the remote node, as well as a route to the management IP address of the remote node. For each of these routes, the next hop IP is the BVI interface IP of the remote node, which goes via the BVI interface of the local node.

POD VRF包含几个静态路由，指向其他节点的BVI IP地址。对于每个节点来说，它是指向远程节点的PODSubnet和VppHostSubnet的路由，以及指向远程节点的管理IP地址的路由。对于这些路由中的每一个，下一跳IP是远程节点的BVI接口IP，它通过本地节点的BVI接口。

The VXLAN tunnels and the static routes pointing to them are added/deleted on each VPP, whenever a node is added/deleted in the k8s cluster.

每当k8s集群中的一个节点被添加/删除时，VXLAN隧道和指向它们的静态路由就会在每个VPP上被添加/删除。

#### More info

Please refer to the [Packet Flow Dev Guide](https://github.com/contiv/vpp/blob/master/docs/dev-guide/PACKET_FLOW.md) for more detailed description of paths traversed by request and response packets inside Contiv/VPP Kubernetes cluster under different situations.
