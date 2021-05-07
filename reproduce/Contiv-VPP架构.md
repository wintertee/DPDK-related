# Architecture

<https://contivpp.io/docs/architecture/contiv-vpp-arch/>

Contiv-VPP consists of several components, each of them packed and shipped as a Docker container. Two of them deploy on Kubernetes master node only:

* [Contiv KSR](https://contivpp.io/docs/architecture/contiv-vpp-arch/#contiv-ksr)
* [Contiv CRD + Netctl](https://contivpp.io/docs/architecture/contiv-vpp-arch/#Contiv-CRD-netctl)
* [Contiv ETCD](https://contivpp.io/docs/architecture/contiv-vpp-arch/#contiv-etcd)

and the rest of them deploy on all nodes within the k8s cluster (including the master node):

* [Contiv vSwitch](https://contivpp.io/docs/architecture/contiv-vpp-arch/#contiv-vswitch)
* [Contiv CNI](https://contivpp.io/docs/architecture/contiv-vpp-arch/#contiv-cni)
* [Contiv STN](https://contivpp.io/docs/architecture/contiv-vpp-arch/#contiv-stn)
* [Contivpp UI](https://contivpp.io/docs/architecture/contiv-vpp-arch/#contivpp-UI)
* [Contivpp System Flow](https://contivpp.io/docs/architecture/contiv-vpp-arch/#contivpp-system-flow)

The following section briefly describes the individual Contiv components, which are displayed as orange boxes on the picture below:

![contivpp arch](https://contivpp.io/img/what-is-contiv-vpp/contivpp-v2-arch-new.png)

### Contiv KSR

Contiv KSR (Kubernetes State Reflector)is an agent that subscribes to k8s control plane, watches k8s resources and propagates all relevant cluster-related information into the Contiv ETCD data store. Other Contiv components do not access the k8s API directly, they subscribe to Contiv ETCD instead. For more information on KSR, read the [KSR Readme](https://github.com/contiv/vpp/blob/master/cmd/contiv-ksr/README.md).

Contiv KSR(Kubernetes State Reflector)是一个代理，它订阅k8s控制平面，监视k8s资源，并将所有相关集群相关信息传播到Contiv ETCD数据存储中。其他Contiv组件不直接访问k8s API，而是订阅Contiv ETCD。有关KSR的更多信息，请阅读[KSR Readme](https://github.com/contiv/vpp/blob/master/cmd/contiv-ksr/README.md)。

### Contiv CRD netctl

Contiv CRD handles k8s Custom Resource Definitions defined in k8s API and processes them into configuration in Contiv ETCD. Currently it covers Contiv-specific configuration of individual k8s nodes such as IP address and default gateway, etc. Apart from this functionality, it also runs periodic validation of the topology, and exports the results as another CRD entry. The `contiv-netctl` tool which sits in the same Docker container can be used to explore runtime state of the cluster, such us current IPAM assignments, VPP state etc., or to execute a debug CLI on any of the VPPs in the cluster.

Contiv CRD处理k8s API中定义的k8s自定义资源定义，并将其处理成Contiv ETCD中的配置。目前它涵盖了Contiv对单个k8s节点的具体配置，如IP地址和默认网关等。除此功能外，它还会定期运行拓扑验证，并将结果作为另一个CRD条目导出。坐落在同一个Docker容器中的contiv-netctl工具可以用来探索集群的运行时状态，比如我们当前的IPAM分配、VPP状态等，或者在集群中的任何一个VPP上执行调试CLI。

### Contiv ETCD

Contiv-VPP uses its own instance of ETCD database for storage of k8s cluster-related data reflected by KSR, which are then accessed by Contiv vSwitch Agents running on individual nodes. Apart from the data reflected by KSR, ETCD also stores persisted VPP configuration of individual vswitches (mainly used to restore the operation after restarts), as well as some more internal metadata.

Contiv-VPP使用自己的ETCD数据库实例来存储KSR反映的k8s集群相关数据，然后由运行在各个节点上的Contiv vSwitch Agents访问。除了KSR反映的数据，ETCD还存储了各个vSwitch的持久化VPP配置（主要用于重启后的恢复操作），以及一些更多的内部元数据。

### Contiv vSwitch

vSwitch is the main networking component that provides the connectivity to PODs. It deploys on each node in the cluster, and consists of two main components packed into a single Docker container: VPP and Contiv VPP Agent.

vSwitch是为POD提供连接的主要网络组件，它部署在集群中的每个节点上，由两个主要组件组成，打包成一个Docker容器。它部署在集群中的每个节点上，由两个主要组件打包成一个Docker容器。VPP和Contiv VPP Agent。

**VPP** is the data plane software that provides the connectivity between PODs, host Linux network stack and data-plane NIC interface controlled by VPP:

* PODs are connected to VPP using TAP interfaces wired between VPP and each POD network namespace, 
* host network stack is connected to VPP using another TAP interface connected to the main (default) network namespace, 
* data-plane NIC is controlled directly by VPP using DPDK. Note that this means that this interface is not visible to the host Linux network stack, and the node either needs another management interface for k8s control plane communication, or [STN (Steal The NIC)](https://github.com/contiv/vpp/blob/master/docs/SINGLE_NIC_SETUP.md) deployment must be applied.

**VPP**是数据平面软件，提供POD、主机Linux网络栈和VPP控制的数据平面NIC接口之间的连接。

* POD通过VPP与每个POD网络命名空间之间的有线TAP接口与VPP连接。
* 主机网络协议栈使用另一个连接到主（默认）网络命名空间的TAP接口连接到VPP。
* 数据面的网卡由VPP使用DPDK直接控制。需要注意的是，这意味着这个接口对主机Linux网络栈是不可见的，节点要么需要另一个管理接口来实现k8s控制平面通信，要么必须应用STN（Steal The NIC）部署。

**Contiv-VPP Agent** is the control plane part of the vSwitch container. It is responsible for configuring the VPP according to the information gained from ETCD and requests from Contiv STN. It is based on the [Ligato VPP Agent](https://github.com/ligato/vpp-agent) code with extensions that are related to k8s. For communication with VPP, it uses VPP binary API messages sent via shared memory using [GoVPP](https://wiki.fd.io/view/GoVPP). For connection with Contiv STN, the agent acts as a GRPC server serving CNI requests forwarded from the Contiv CNI.

**Contiv-VPP Agent** 是vSwitch容器的控制平面部分。它负责根据从ETCD获得的信息和Contiv STN的请求配置VPP。它基于[Ligato VPP Agent](https://github.com/ligato/vpp-agent)代码，与k8s相关的扩展。对于与VPP的通信，它使用[GoVPP](https://wiki.fd.io/view/GoVPP)通过共享内存发送的VPP二进制API消息。对于与Contiv STN的连接，代理作为GRPC服务器服务于从Contiv CNI转发的CNI请求。

### Contiv CNI

Contiv CNI is a simple binary that implements the [Container Network Interface](https://github.com/containernetworking/cni) API and is being executed by Kubelet upon POD creation and deletion. The CNI binary just packs the request into a GRPC request and forwards it to the Contiv VPP Agent running on the same node, which then processes it (wires/unwires the container) and replies with a response, which is then forwarded back to Kubelet.

Contiv CNI是一个简单的二进制文件，它实现了 [Container Network Interface](https://github.com/containernetworking/cni) API，并在POD创建和删除时被Kubelet执行。CNI二进制文件只是将请求打包成GRPC请求，并将其转发给运行在同一节点上的Contiv VPP代理，然后由其进行处理（给容器接线/解线），并回复一个响应，然后再转发给Kubelet。

### Contiv STN

As already mentioned, the default setup of Contiv-VPP requires 2 network interfaces per node: one controlled by VPP for data facing PODs and one controlled by the host network stack for k8s control plane communication. In case that your k8s nodes do not provide 2 network interfaces, contivpp.io can work in the single NIC setup, when the interface will be “stolen” from the host network stack just before starting the VPP and configured with the same IP address on VPP, as well as on the host-VPP interconnect TAP interface, as it had in the host before it. For more information on STN setup, read the [Single NIC Setup README](https://github.com/contiv/vpp/blob/master/docs/SINGLE_NIC_SETUP.md).

前面已经说过，Contiv-VPP的默认设置要求每个节点有2个网络接口：一个由VPP控制，用于面向POD的数据，一个由主机网络栈控制，用于k8s控制平面通信。如果你的k8s节点没有提供2个网络接口，contivpp.io可以在单网卡设置中工作，这时接口将在启动VPP之前从主机网络栈中 "偷 "出来，并在VPP上配置相同的IP地址，以及在主机-VPP互连TAP接口上配置相同的IP地址，就像它之前在主机中一样。关于STN设置的更多信息，请阅读[Single NIC Setup README](https://github.com/contiv/vpp/blob/master/docs/SINGLE_NIC_SETUP.md)。

### Contivpp UI

Contivpp UI is composed of two components. The first is a customized GUI enabling the user to display the k8s cluster including the Contiv-VPP system pods. It also allows access to the configuration (e.g. IPAM), k8s, contivpp and namespace and k8s services mapped to contiv vswitches. The other component is a proxy providing REST APIs to the front-end GUI and per-vswitch APIs to the contiv vswitches deployed in the cluster. The contivpp UI is deployed as a docker container and is optional both in the production and demo systems.

Contivpp UI由两部分组成。第一个是定制的GUI，使用户能够显示k8s集群，包括Contiv-VPP系统Pod。它还允许访问配置（如IPAM）、k8s、contivpp和命名空间以及映射到contiv vswitches的k8s服务。另一个组件是一个代理，为前端GUI提供REST API，为集群中部署的contiv vswitches提供per-vswitch API。contivpp UI以docker容器的形式部署，在生产和演示系统中都是可选的。

### Contivpp Flow

![contivpp arch](https://contivpp.io/img/what-is-contiv-vpp/contiv-flow.png)
