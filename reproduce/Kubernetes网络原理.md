# Kubernetes网络原理

来自专栏 [人工智能技术栈](https://www.zhihu.com/column/c_1105070845327900672)

最近在工作中遇到kubernetes网络的问题，因此，决定好好研究下kubernetes的网络原理。参见书籍<Kubernetes权威指南>。

**Kubernetes网络模型**

首先，我们先来看一下kubernetes的网络模型。

Kubernetes网络模型设计的基础原则：**每个Pod拥有一个独立的IP地址，而且所有Pod都在一个可以直接连通、扁平的网络空间中**。这种网络模型被称为**IP-per-Pod模型**。

IP-per-Pod模型使得：1. 所有Pod及其内部container（不管在不在同一个node上）都可以在不用NAT的方式直接相互访问；2.Pod内部的所有container共享一个网络堆栈，包括IP地址、网络设备、配置等，即同一个Pod内的容器可以通过localhost来连接对方的端口。

Google设计的公有云GCE默认支持Kubernetes网络模型，亚马逊提供的公有云也支持这种网络模型。但是，我们在部署私有云来运行kubernetes+docker集群之前，需要自己搭建出符合kubernetes网络模型的网络环境。

Kubernetes网络依赖于Docker，而Docker的网络又离不开Linux OS内核特性的支持。

**Docker网络基础**

这里简单介绍Docker使用的，与Linux网络有关的技术，包括：网络命名空间(Network Namespace)，Veth设备对，网桥，iptables和路由。

- 网络命名空间

为了在一个宿主机上虚拟多个不同的网络环境，需要支持多个网络协议栈，Linux引入网络命名空间的概念。不同网络命名空间的网络协议栈是完全隔离的，之间无法通信。Docker利用网络命名空间来实现不同容器之间的网络隔离。

Linux将网络协议栈中使用的所有全局变量放入Namespace字段，而网络协议栈的函数调用加入Namespace参数。同时，为了后向兼容，内核代码隐式使用Namespace中的变量。

![img](https://pic2.zhimg.com/80/v2-c83c7060791e33026061d58c40da4371_1440w.jpg)

新生成的私有Namespace中只有回环设备(名为lo且是停止状态)，其他设备默认不存在，需要手工创建。Docker容器中的各类网络栈设备都是Docker Daemon启动时自动创建和配置的。

所有网络设备都只能属于一个Namespace，物理设备通常只能关联root namespace，虚拟设备则可关联给定的namespace并可在不同namespace之间移动，但网络设备是否能转移需要查看其NETIF_F_ETNS_LOCAL属性，若为on则不能转移。可以使用命令ethtool来查看设备是否可转移。

```bash
＃ ethtool -k br0
netns-local: on [fixed]
```

常见的namespace的操作如下：

```bash
ip netns  // show all namespace
ip netns del <name> &>/dev/null // delete namespace
ip netns add <name>  // create namespace
ip netns exec <name> <command>  // execute command in namespace
ip netns exec <name> bash  // enter namespace and execute command
ip link set br0 netns ns1  //Put network device br0 into namespace ns1
```

- Veth设备对

Namespace代表独立的协议栈，之间是隔离的，彼此不能通信。Veth用来连通不同的namespace，对应的Veth设备对分别处于2个namespace。

![img](https://pic3.zhimg.com/80/v2-3e9d7bebfde51e2775a37d325bbe4bce_1440w.jpg)

下面是创建Veth设备对的命令：

```bash
# ip link add veth0 type veth peer name veth1  //创建veth设备对veth0和veth1
# ip link show //查看所有网络接口
# ip link set veth1 netns netns1 //将veth1迁移到namespace netns1
# ip netns exec netns1 ip link show  //查看namespace netns1中的所有网络接口
# ip netns exec netns1 ip addr add 10.1.1.1/24 dev veth1 //为veth1设备分配ip地址
# ip addr add 10.1.1.2/24 dev veth0  //为veth0设备分配ip地址
# ip netns exec netns1 ip link set dev veth1 up  //启动网络设备veth1
# ip link set dev veth0 up //启动网络设备veth0
// 这样两个namespace之间就可以通信了
# ping 10.1.1.1
PING 10.1.1.1 (10.1.1.1) 56(84) bytes of data.
# ip netns exec netns1 ping 10.1.1.2
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.
// 查找veth设备的peer在什么namespace
# ip netns exec netns1 ethtool -S veth1 //查看设备对端接口在设备列表中对序列号为5
NIC staticstics:
    peer_ifindex: 5
# ip netns exec netns2 ip link | grep 5 //在netns2中找到设备号5对veth0便是对端设备
```

Docker除了将Veth放入容器内，还将其名字改成eth0。Docker中，Veth设备对也是连通容器与宿主机的主要网络设备。

下面是使用namespace和veth设备的示例。我们分别创建namespace ns0和ns1并在其中分别创建veth设备veth0和veth1

```bash
[root@tw-node3227 ~]# ip netns add ns1
[root@tw-node3227 ~]# ip netns 
ns1
ns0
[root@tw-node3227 ~]# ip netns exec ns0 ip link add veth0 type veth peer name veth1
[root@tw-node3227 ~]# ip netns exec ns0 ip link show
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: veth1@veth0: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether aa:e5:26:27:f8:d8 brd ff:ff:ff:ff:ff:ff
3: veth0@veth1: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether 3e:d2:dc:14:e4:7b brd ff:ff:ff:ff:ff:ff
[root@tw-node3227 ~]# ip netns exec ns0 ip link set veth1 netns ns1
[root@tw-node3227 ~]# ip netns exec ns0 ip link show
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
3: veth0@if2: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether 3e:d2:dc:14:e4:7b brd ff:ff:ff:ff:ff:ff link-netnsid 0
[root@tw-node3227 ~]# ip netns exec ns1 ip link show
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: veth1@if3: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether aa:e5:26:27:f8:d8 brd ff:ff:ff:ff:ff:ff link-netnsid 0
[root@tw-node3227 ~]# ip netns exec ns0 ip addr add 10.1.1.1/24 dev veth0
[root@tw-node3227 ~]# ip netns exec ns0 ip link show
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN mode DEFAULT 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
3: veth0@if2: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT qlen 1000
    link/ether 3e:d2:dc:14:e4:7b brd ff:ff:ff:ff:ff:ff link-netnsid 0
[root@tw-node3227 ~]# ip netns exec ns0 ip addr show
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
3: veth0@if2: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN qlen 1000
    link/ether 3e:d2:dc:14:e4:7b brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.1.1/24 scope global veth0
       valid_lft forever preferred_lft forever
[root@tw-node3227 ~]# ip netns exec ns1 ip addr add 10.1.1.2/24 dev veth1
[root@tw-node3227 ~]# ip netns exec ns1 ip addr show
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: veth1@if3: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN qlen 1000
    link/ether aa:e5:26:27:f8:d8 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.1.2/24 scope global veth1
       valid_lft forever preferred_lft forever
[root@tw-node3227 ~]# ip netns exec ns0 ip link set dev veth0 up
[root@tw-node3227 ~]# ip netns exec ns1 ip link set dev veth1 up
[root@tw-node3227 ~]# ip netns exec ns0 ping 10.1.1.2
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.
64 bytes from 10.1.1.2: icmp_seq=1 ttl=64 time=0.102 ms
64 bytes from 10.1.1.2: icmp_seq=2 ttl=64 time=0.045 ms
64 bytes from 10.1.1.2: icmp_seq=3 ttl=64 time=0.051 ms
64 bytes from 10.1.1.2: icmp_seq=4 ttl=64 time=0.044 ms
64 bytes from 10.1.1.2: icmp_seq=5 ttl=64 time=0.048 ms
64 bytes from 10.1.1.2: icmp_seq=6 ttl=64 time=0.073 ms
64 bytes from 10.1.1.2: icmp_seq=7 ttl=64 time=0.041 ms
64 bytes from 10.1.1.2: icmp_seq=8 ttl=64 time=0.044 ms
64 bytes from 10.1.1.2: icmp_seq=9 ttl=64 time=0.042 ms
^C
--- 10.1.1.2 ping statistics ---
9 packets transmitted, 9 received, 0% packet loss, time 7999ms
rtt min/avg/max/mdev = 0.041/0.054/0.102/0.020 ms
[root@tw-node3227 ~]# ip netns exec ns1 ping 10.1.1.1
PING 10.1.1.1 (10.1.1.1) 56(84) bytes of data.
64 bytes from 10.1.1.1: icmp_seq=1 ttl=64 time=0.073 ms
64 bytes from 10.1.1.1: icmp_seq=2 ttl=64 time=0.045 ms
64 bytes from 10.1.1.1: icmp_seq=3 ttl=64 time=0.064 ms
64 bytes from 10.1.1.1: icmp_seq=4 ttl=64 time=0.066 ms
^C
--- 10.1.1.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3000ms
rtt min/avg/max/mdev = 0.045/0.062/0.073/0.010 ms
[root@tw-node3227 ~]# ip netns exec ns0 ethtool -S veth0
NIC statistics:
     peer_ifindex: 2
[root@tw-node3227 ~]# ip netns exec ns1 ip link | grep 2
2: veth1@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT qlen 1000
    link/ether aa:e5:26:27:f8:d8 brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

- 网桥

网桥用于不同网络中主机之间的相互通信，二层的虚拟网络设备，将若干个网络接口连接起来使其能相互间转发报文。

网桥读取报文中的目标MAC地址并与自己记录的MAC地址表结合来决定报文转发的目标网络接口，当不知道怎么转发时，广播报文。网桥的MAC地址表会设置超时时间,默认5min，若收到对应端口MAC地址回发的包，则重置超市时间，否则，MAC地址失效，进行广播处理。

交换机只是一个二层设备，接收到的报文要么转发，要么丢弃。而网桥接收的报文除了转发和丢弃外，还可能被送到网络协议栈的上层（网络层），从而被自己消化，所以网桥可以被看作二层设备或三层设备。

Linux内核通过网桥设备绑定多个以太网接口设备，从而将它们桥接起来。网桥设备有IP地址。下图中，网桥br0绑定了eth0和eth1。网络协议栈的上层只看得到br0，上层将报文发送到br0，br0决定转发给eth0，eth1还是广播；同时，从eth0和eth1接收的报文被提交到br0，进而判断报文被转发、丢弃还是提交到上层。有时，以太网接口eth2可以作为报文的源地址或目标地址，绕过网桥，直接参与报文发送和接收。

![img](https://pic2.zhimg.com/80/v2-b825a7a6acac25e3be55a206fe2bb7fd_1440w.jpg)

下面是网桥操作的一些命令。

```text
# brctl show //查看当前的所有网桥设备
# brctl addbr <name>   // 新增网桥设备
# brctl delbr <name>   // 删除网桥设备
# brctl showbr br0 //查看网桥绑定的网口
# brctl addif <name> ethx //为网桥设备增加网口，在Linux中，网口实际上是物理网卡
# brctl delif <brname> <ifname> //删除网口设备
# ifconfig ethx 0.0.0.0  //网口在链路层工作不需要IP地址
# ifconfig brx xxx.xxx.xxx.xxx  //为网桥配置IP地址
```

- iptables和Netfilter

Linux网络协议栈中有一组回调函数挂接点，通过回调函数挂接点的钩子函数可以在处理数据包的过程中进行一些操作，包括过滤、修改、丢弃等。挂接点技术由Netfilter和iptables实现。

Netfilter运行在内核模式，负责执行挂接规则；iptables为运行在用户模式的进程，负责协助和维护内核中Netfilter的各种规则表。

Netfilter可以挂接的规则点有如下5个。支持的表类型有RAW, MANGLE, NAT, FILTER,优先级依次降低。

![img](https://pic2.zhimg.com/80/v2-b1a32a192084e55d4d4724c4b86053d5_1440w.jpg)

同时，不同的挂接点只能使用相应类型的table。数据处理时，依次调用挂接点上的所有挂钩函数，直到数据包被明确拒绝或接收。

![img](https://pic3.zhimg.com/80/v2-dd1a41038bff37325ceeef30997bc2ba_1440w.jpg)

每个规则包括以下内容：表类型，挂接点类型，匹配的参数，匹配后的操作。匹配的参数可能是源、目的网络接口、地址、端口，协议类型等。

iptables命令用于协助用户维护各种规则，下面是该命令的使用示例。

```bash
iptables-save //命令方式打印iptables的内容
iptables-vnL //以另一种格式显示Netfilter的内容
// iptables命令
Usage: iptables -[ACD] chain rule-specification [options]
       iptables -I chain [rulenum] rule-specification [options]
       iptables -R chain rulenum rule-specification [options]
       iptables -D chain rulenum [options]
       iptables -[LS] [chain [rulenum]] [options]
       iptables -[FZ] [chain] [options]
       iptables -[NX] chain
       iptables -E old-chain-name new-chain-name
       iptables -P chain target [options]
       iptables -h (print this help information)

Commands:
Either long or short options are allowed.
  --append  -A chain		Append to chain
  --check   -C chain		Check for the existence of a rule
  --delete  -D chain		Delete matching rule from chain
  --delete  -D chain rulenum
				Delete rule rulenum (1 = first) from chain
  --insert  -I chain [rulenum]
				Insert in chain as rulenum (default 1=first)
  --replace -R chain rulenum
				Replace rule rulenum (1 = first) in chain
  --list    -L [chain [rulenum]]
				List the rules in a chain or all chains
  --list-rules -S [chain [rulenum]]
				Print the rules in a chain or all chains
  --flush   -F [chain]		Delete all rules in  chain or all chains
  --zero    -Z [chain [rulenum]]
				Zero counters in chain or all chains
  --new     -N chain		Create a new user-defined chain
  --delete-chain
            -X [chain]		Delete a user-defined chain
  --policy  -P chain target
				Change policy on chain to target
  --rename-chain
            -E old-chain new-chain
				Change chain name, (moving any references)
```

下面是iptables-save的输出解释，图片来源于[iptables-save-help](https://link.zhihu.com/?target=https%3A//www.cnblogs.com/sixloop/p/iptables-save-help.html)：

![img](https://pic4.zhimg.com/80/v2-7ce05edb1b9c5e77e078839d283d9d27_1440w.jpg)

- 路由

路由功能由IP层维护的路由表来实现，先判断报文IP是否与本主机IP相同，若相同，则将报文发送到传输层；否则，根据路由表将报文转发，若路由表中没有匹配的目标地址，转发到默认路由器，若默认路由器不存在，将生成ICMP主机不可达的错误并返回给应用程序。

路由表中的条目包括：目标IP地址，下一跳IP地址，标志(目标IP地址是主机地址还是网络地址)，网络接口规范。路由表至少包含2个表，LOCAL和MAIN。LOCAL路由表在配置网络设备地址时自动创建，包含所有本地设备地址；MAIN路由表可以静态配置生成，也可以使用动态路由发现协议生成，用于网络IP地址的转发。

动态路由发现协议一般使用组播功能发送路由发现数据，动态交换和获取网络的路由信息，并更新到路由表中。Linux下支持路由发现协议的开源软件有Quagga和Zebra。

常见命令：

```text
# ip route show table local type local  //查看local路由表的内容
10.10.10.245 dev kube-ipvs0  proto kernel  scope host  src 10.10.10.245 
10.10.10.246 dev kube-ipvs0  proto kernel  scope host  src 10.10.10.246 
10.11.25.0 dev fl1  proto kernel  scope host  src 10.11.25.0 
10.11.25.1 dev brfl1  proto kernel  scope host  src 10.11.25.1 
127.0.0.0/8 dev lo  proto kernel  scope host  src 127.0.0.1 
127.0.0.1 dev lo  proto kernel  scope host  src 127.0.0.1 
172.16.3.127 dev eth1  proto kernel  scope host  src 172.16.3.127 

# ip route list //查看当前路由表
default via 172.16.0.1 dev eth1  proto static  metric 100 
10.11.9.0/24 via 10.11.9.0 dev fl1 onlink 
10.11.25.0/24 dev brfl1  proto kernel  scope link  src 10.11.25.1 
10.11.76.0/24 via 10.11.76.0 dev fl1 onlink 
10.11.91.0/24 via 10.11.91.0 dev fl1 onlink 
172.16.0.0/22 dev eth1  proto kernel  scope link  src 172.16.3.127  metric 100 
```

---------------------> nc command

使用nc command可以搭建聊天工具，如在主机172.16.1.127上监听端口20000，然后在其他主机上连接到172.16.1.127:20000,则一方打印的消息会显示在两个终端上。

```bash
//通过下面命令来获取主机的局域网IP地址
ifconfig | grep "inet " | grep -v 127.0.0.1

//172.16.1.127上监听20000端口
# nc -l 20000 
hello 128
hello 127

//172.16.1.128上连接172.16.1.127:20000
# nc 172.16.1.127 20000
hello 128
hello 127
```

<--------------------

**Docker网络实现**

Docker支持4类网络模式，Kubernetes通常只会使用bridge模式。

- host模式 --net=host指定
- container模式 --net=container:NAME_or_ID指定
- none模式 --net=none指定
- bridge模式 --net=bridge指定，为默认设置

bridge模式下，Docker Daemon第一次启动时会创建虚拟网桥，默认名称为docker0，并按照RPC1918在私有网络空间中为网桥分配子网。Docker创建的每一个container，都会创建Veth设备对来连接网桥和container内的eth0设备，eth0的IP地址从网桥的地址段内分配。

![img](https://pic4.zhimg.com/80/v2-471aac423d2f00df8d94a5b11cf694f3_1440w.jpg)

上图中，网桥的ip地址为ip1，容器2的IP地址为ip2，从地址段中选择，相应的MAC地址根据IP地址在02:42:ac:11:00:00-02:42:ac:11:ff:ff的范围内生成，确保不会ARP冲突。启动后，Docker还将Veth对的名称映射到eth0网络接口，ip3为主机的网卡地址。

现在，相同主机内的容器之间可以相互通信，但不同主机上的容器不能相互通信(不同主机上的docker0地址段可能是一样的)。为了实现容器之间跨节点通信，必须在主机的地址上分配端口，通过端口路由或代理到容器。但协调端口分配十分困难。

下面我们将展示不同阶段的网络情况。

- Docker启动后

在bridge模式下，Docker Daemon启动时创建docker0网桥。下面是启动Docker Daemon但没启动任何容器的网络协议栈的配置情况。

Docker创建了docker0网桥并添加了iptables规则，都处于root命名空间中。NAT表中3个规则，前2个规则目的地址为local类型且分别为PREROUTING和OUTPUT链都会被路由到DOCKER链，第3个规则表示目的地址不是docker0且源地址为172.17.0.0/16的都经过MASQUERADE将源地址从容器地址修改为宿主机的网卡IP地址。

![img](https://pic4.zhimg.com/80/v2-7c491d1765fc9c2fe3c618fa29a73c53_1440w.jpg)

![img](https://pic2.zhimg.com/80/v2-02333aa68ce9dee65b4a15ef5cbe9a2d_1440w.jpg)

- 启动Docker容器

-启动不带端口的容器

下面是区别的地方。宿主机的Netfilter和路由表都没有变化。宿主机上的Veth对创建并连接到容器内。

![img](https://pic2.zhimg.com/80/v2-327f44f80535b4527b12e35c1ae1f641_1440w.jpg)

下面是容器内的ip地址和路由。默认停止的回环设备lo已经启动，而且外面宿主机连接进来的Veth设备也被命名为eth0并设置IP地址为172.17.0.10.

![img](https://pic2.zhimg.com/80/v2-1b6d973574ca7a30321c86738d82cae5_1440w.jpg)

-启动带端口的容器

```text
docker run --name register -d -p 1180:5000 registry
```

下面是区别的地方。Docker服务在NAT和FILTER表添加的DOCKER链规则是为了端口映射，将宿主机的1180端口映射到容器的5000端口。

```text
# iptables-save
*nat
-A POSTROUTING -s 172.17.0.19/32 -d 172.17.0.19/32 -p tcp -m tcp --dport 5000 -j MASQUERADE
-A DOCKER ! -i docker0 -p tcp -m tcp --dport 1180 -j DNAT --to-destination 172.17.0.19:5000

*filter
-A DOCKER -d 172.17.0.19/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport 5000 -j ACCEPT
```

Docker网络局限

Docker一开始并没有考虑多主机互联的网络解决方案。虚拟化技术中最复杂的就是虚拟化网络技术，门槛很高，Docker避开该雷区，让其他专业人员用现有的虚拟化网络技术解决Docker主机的互联问题。

Docker收购Socketplane公司来提供网络解决方案Libnetwork。

![img](https://pic2.zhimg.com/80/v2-23aed3c484d4f5ce722e4dec0d5215c1_1440w.jpg)

**Kubernetes的网络实现**

Kubernetes的网络设计主要解决下面几个问题：

- 容器之间的直接通信

Pod内的所有容器共享相同网络命名空间和Linux协议栈，可以使用localhost访问彼此的端口。

![img](https://pic4.zhimg.com/80/v2-2382527de6630c625c2e22c218c3dcaf_1440w.jpg)

- Pod之间的通信

Pod具有真实的全局IP地址，相同Node内的不同Pod之间可以直接采用对方Pod的IP地址通信。Pod之间的通信分为**相同Node上Pod的通信**和**不同Node上Pod的通信**。

下面图示可以看出，Pod1和Pod2通过Veth连接到docker0网桥，IP1/IP2/IP3都是从docker0网段上获取，属于相同网段。Pod1和Pod2的Linux协议栈上，默认路由都是docker0地址，即所有非本地地址的网络数据都默认由docker0转发，因此可以直接通信。

![img](https://pic3.zhimg.com/80/v2-a5c4641dbafacdcd4a6d06b3a2c4340e_1440w.jpg)

Kubernetes会在etcd中记录所有正在运行的Pod的IP分配信息（作为service的endpoint）。支持不同Node上Pod之间的通信需要满足下面2个条件：1.整个k8s集群中对Pod的IP分配进行规划，不能冲突；2.找到方法将Pod的IP和Node的IP关联，通过关联让Pod可以相互访问。

实现条件1，需要在部署k8s时对docker0的网络地址段进行规划，保证不同Node的docker0地址段不冲突，可以手动配置，也可以由Flannel管理资源池的分配。

实现条件2，要求知道目标Pod的IP地址挂在哪个Node上，将数据先发送到Node的IP地址，然后在宿主机上转发给docker0。谷歌的GCE支持该条件，而K8s也假设底层已经支持该条件。**在不使用GCE的私有云中，需要额外的网络配置来实现k8s对网络的要求。**有不少开源软件支持k8s对网络的要求。

![img](https://pic4.zhimg.com/80/v2-8eafdf82a68e24526fa1da77ea81693f_1440w.jpg)

- Pod与Service的通信
- 集群外部与内部组件的通信

**Pod和Service网络实战**

本节通过网络实战来了解k8s的网络模型。实验环境如下：

![img](https://pic1.zhimg.com/80/v2-fa2b57f8666446dfb062ffb710300f68_1440w.jpg)

K8S网络模型中，所有Pod都是可以直接访问的，不需要在Node上做端口映射。因此，在网络层可以将Node看作是路由器，通过在每个Node上配置相应静态路由项来实现。192.168.1.129节点上配置的路由项如下：

```bash
# route add -net 10.1.20.0 netmask 255.255.255.0 gw 192.168.1.130
# route add -net 10.1.30.0 netmask 255.255.255.0 gw 192.168.1.131
```

这样，实验环境的网络图如下。

![img](https://pic4.zhimg.com/80/v2-c3a055899df9a3ac2f78a9658e34acf3_1440w.jpg)

-部署Pod

为了便于观察，我们在空的k8s上部署Pod。Node1上的网络接口如下,只有docker0网桥和本地地址的网络端口。

```text
# ifconfig
docker0: flags=4099<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500
      inet 10.1.10.1 netmask 255.255.255.0 broadcast 10.1.10.255
eno16777736: flags=4163<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500
      inet 192.168.1.129 netmask 255.255.255.0 broadcast 192.168.1.255
lo: flags=73<UP,LOOPBACK,RUNNING> mtu 65536
      inet 127.0.0.1 netmask 255.0.0.0
```

下面创建K8S ReplicationController，其包含1个replica，使用端口80，部分信息如下。

![img](https://pic1.zhimg.com/80/v2-fd2f1da08b7a3ce90759181e21c69998_1440w.jpg)

使用kubectl create来创建，其被分配到Node2。在Node2上查看正在运行到container,发现有2个，一个是我们启动到容器，另一个是pause。

![img](https://pic4.zhimg.com/80/v2-473c717701ccb0156c544fe75fb609fb_1440w.jpg)

查看2个container到网络模型：pause容器的网络模型为Docker默认的bridge，而我们的容器使用映射容器的模型，而且映射目标容器为pause容器。Pod中的所有容器使用相同到网络空间和IP地址，都会被映射到pause容器，这样，只需要在pause容器执行端口映射规则，简化端口映射过程。

![img](https://pic1.zhimg.com/80/v2-b91ccdb6abb4965a24e83c5c05a4078c_1440w.jpg)

Pod到网络模型类似于下图。图中显示pause容器将端口80到流量转发到相关容器。但实际上是应用容器直接监听这些端口，不用pause容器转发。Pod内部实际容器到端口映射都显示到pause容器，负责接管Pod到Endpoint，使用docker port命令查看。此时，Node上没有增加iptables规则来处理到Pod到请求。

![img](https://pic4.zhimg.com/80/v2-67ccaf797cfbd5c092f5e3ca553cce97_1440w.jpg)

![img](https://pic4.zhimg.com/80/v2-99f4fb18c696b048183e6b35ce6459eb_1440w.jpg)

-部署service

清理k8s环境后创建如下service。

![img](https://pic3.zhimg.com/80/v2-479f4cb93d823c460babeddbab6cff8a_1440w.jpg)

创建之后，service被分配20.1.244.75的IP地址。

![img](https://pic1.zhimg.com/80/v2-9381b7bbb1459d22744c09850d73f89c_1440w.jpg)

查看iptables的变化。第一条是PREROUTING链的规则，所有访问20.1.244.75:80的流量被重定向到59528端口。第二行是OUTPUT链的规则，类似第一条。kube-proxy为每个新建服务关联随机端口，如这里的59528，并监听该端口为服务创建负载均衡对象。所有流量都被导入kube-proxy中。

![img](https://pic4.zhimg.com/80/v2-2c92f1f570d62f6025984271bb69d377_1440w.jpg)

下面创建ReplicationController。

![img](https://pic1.zhimg.com/80/v2-1d2ce0d1297ba2a6d734dcd7a7fa4c0c_1440w.jpg)

创建之后的pod分配如下：

![img](https://pic3.zhimg.com/80/v2-8f48304a958707f68d83694eafaf2a76_1440w.jpg)

现在的实验环境。

![img](https://pic4.zhimg.com/80/v2-42a0a5181850e36c2f510a7dd87135b7_1440w.jpg)

上面重定向规则的结果就是针对目标地址为服务IP的流量，将kube-proxy变成中间夹层。

当在node1上的容器中访问service时，此次访问调用Node3上的Pod，其网络访问如下所示。在Node1上的容器访问相同节点的kube-proxy，然后该kube-proxy直接将访问代理到Node3上的Pod，绕过Node3上的kube-proxy。kube-proxy作为全功能的代理服务器管理了2个TCP连接：从容器到kube-proxy; 从kube-proxy到负载均衡到目标Pod。

![img](https://pic3.zhimg.com/80/v2-4404842f3932ebabb3a8cf08eb184fa6_1440w.jpg)

**CNI网络模型**

目前主流的容器网络模型包括Docker提出的Container Network Model(CNM)模型和CoreOS提出的Container Network Interface(CNI)模型。

-CNM模型

CNM模型主要通过Network Sandbox, Endpoint, Network这3个组件实现。

- Network Sandbox 容器内部的网络栈，包括网络接口、路由表、DNS等配置的管理，可以使用Linux的网络命名空间实现。一个Sandbox可以包含多个Endpoint。
- Endpoint 用于将容器内的Sandbox与外部网络相连的网络接口，可以使用Veth对实现。一个Endpoint仅能够加入一个Network。
- Network 可以直接互联的Endpoint集合，可以通过Linux网桥实现，一个Network包含多个Endpoint。

![img](https://pic4.zhimg.com/80/v2-d474f7b45b9fa2df347f2ab931697aa3_1440w.jpg)

-CNI模型

下面是CNI模型。CNI定义容器运行环境与网络插件之间的简单接口规范，提供一种应用容器的插件化网络解决方案。

![img](https://pic1.zhimg.com/80/v2-97bf696169c5e1962f80cfb9b19b4ed0_1440w.jpg)

CNI模型中只涉及2个概念：容器和网络。容器是拥有独立Linux网络命名空间的环境；网络表示互连的一组实体，实体拥有各自独立、唯一的IP地址，可以是容器、物理机或其他网络设备。

对容器网络的设置和操作都通过插件来实现，CNI插件包括2类：CNI Plugin和IPAM(IP Address Management) Plugin.前者负责为容器配置网络资源，后者负责对容器的IP地址进行分配和管理。

**Kubernetes网络策略**

为了实现细粒度的容器间网络访问隔离策略，k8s从1.3版本引入**Network Policy**机制。该机制对**Pod间的网络通信进行限制控制**，使用Pod的label作为查询条件来设置允许访问或禁止访问的客户端Pod列表。查询条件可作用于Pod和Namespace两个级别。

K8s通过定义资源对象NetworkPolicy来定义网络策略，策略控制器Policy Controller监听用户设置的NetworkPolicy，通过各Node的Agent进行实际设置。**策略控制器由第三方网络组件提供**，目前Calico, Cilium, Kube-router,Romana, Weave Net等开源项目均支持。

![img](https://pic4.zhimg.com/80/v2-e46f21e7fbf02ebf0ac9a5372f8da0db_1440w.jpg)

默认情况下，对所有Pod都是允许访问的。设置NetworkPolicy用于限制对目标Pod的访问。下面是一个示例。

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```

podSelector选定网络策略作用的**目标Pods**，该例中选择带有标签role=db的Pod。policytypes用于指定网络策略类型，包括ingress和egress，分别限制目标Pod入站和出站的网络限制。**ingress定义访问目标Pod的白名单**，满足from条件的客户端才能访问目标Pod的ports指定的端口号。**egress定义目标Pod能够访问的出站白名单**，只能访问满足to条件的IP和ports定义的Pod。

namespaceSelector和podSelector可以单独设置，也可以组合设置。若仅配置podSelector，表示与目标Pod属于相同Namespace，而组合设置可以设置Pod所属Namespace. 下面是组合设置的示例，表示来源Pod属于有label project=myproject的namespace并且有role=frontend标签。

```yaml
- from:
  - namespaceSelector:
      matchLabels:
        project: myproject
    podSelector:
      matchLabels:
        role: frontend
```

也可以在namespace级别设置默认的网络策略。

```yaml
//默认禁止任何客户端访问该namespace中的所有pod
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress

//允许任何客户端访问该namespace中的所有Pod
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
spec:
  podSelector: {}
  ingress:
  - {}
  policyTypes:
  - Ingress
```

**开源的网络组件**

K8S的网络模型假定所有Pod都在一个可以直接连通的扁平网络空间中。GCE中，该条件天然满足，但在私有云中搭建k8s，需要自己实现这个网络假设，将不同节点上的Docker容器之间的互相访问先打通，然后运行k8s。目前多个开源组件支持容器网络模型，包括Flannel, Open vSwitch, 直接路由和Calico。

- Flannel

Flannel通过2个功能来支持k8s网络模型的假设：1. 为每个Node上的Docker容器分配不冲突的IP地址；2.在这些IP地址之间建立**覆盖网络**(Overlay Network)，通过覆盖网络将数据包原封不动地传递给目标容器。

下图展示Flannel的实现。**Flannel创建flannel0网桥，一端连接docker0网桥，另一端连接flanneld服务进程**。flanneld服务进程连接**etcd**，利用etcd来管理可分配的IP地址段资源，同时监控etcd中每个Pod的实际地址，并在**内存中建立一个Pod节点路由表**。接收到docker0发出的数据包，flanneld利用内存中的Pod节点路由表将该数据包包装起来，利用物理网络的连接将数据包投递到目标flanneld上，从而完成Pod之间的直接地址通信。

Flannel的底层通信协议可选UDP, VxLan, AWS VPC等，通过源flanneld封包，目标flanneld解包，最终docker0收到的就是原始的数据，对容器应用来说是透明的。

![img](https://pic3.zhimg.com/80/v2-d6e57625970328322122a4150514b4a6_1440w.jpg)

Flannel使用集中的etcd存储，每次从同一个公共区域获取地址段并分配给Node上的docker0，从而保证所有Pod的IP地址在同一水平网络且不冲突。Flannel分配好地址段后，通过docker的启动参数--bip将分配的地址段传递给docker。后面的事情由docker完成。

```text
--bip=172.17.18.1/24
```

Flannel引入多个网络插件，网络通信中先赚到flannel0，再转到用户态的flanneld程序，到对端后执行反操作，引入一些网络的时延损耗。另外，Flannel默认采用 UDP作为底层传输协议，不可靠。虽然两端的TCP实现可靠传输，但在大流量、高并发的应用场景下需要反复测试。
