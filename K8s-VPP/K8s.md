# 搭建k8s集群 

## 安装DPDK

见[这里](/DPDK/DPDK.md)

## 配置master node(72)

### 安装kubelet，kubeadm，kubectl

  

``` shell
apt-get update && apt-get install -y apt-transport-https
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
add-apt-repository "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main"
apt-get update
apt-get install kubelet=1.20.5-00 kubeadm=1.20.5-00 kubectl=1.20.5-00
apt-mark hold kubelet kubeadm kubectl
  ```

### 关闭swap

``` shell
  swapoff -a
  ```

### 修改docker驱动

  
  参考 <https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker>>

``` shell
sudo mkdir /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
```

重启docker

``` shell
sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 自动配置VPP

``` shell
git clone https://github.com/contiv/vpp.git
```

``` shell
root@ubuntu:~# mkdir -p /etc/vpp/
root@ubuntu:~/vpp/k8s# ./setup-node.sh
#########################################
#   Contiv - VPP                        #
#########################################
Do you want to setup multinode cluster? [Y/n] y
PCI UIO driver is loaded
The following network devices were found
1) ens160 0000:03:00.0
2) network 0000:0b:00.0
3) ens224 0000:13:00.0
Select interface for node interconnect [1-3]:2
Device 'network' must be shutdown, do you want to proceed? [Y/n] y

unix {
   nodaemon
   cli-listen /run/vpp/cli.sock
   cli-no-pager
   poll-sleep-usec 100
}
nat {
   endpoint-dependent
   translation hash buckets 1048576
   translation hash memory 268435456
   user hash buckets 1024
   max translations per user 10000
}
acl-plugin {
   use tuple merge 0
}
api-trace {
    on
    nitems 5000
}
dpdk {
   dev 0000:0b:00.0
}
socksvr {
   default
}
statseg {
   default
}

File /etc/vpp/contiv-vswitch.conf will be modified, do you want to proceed? [Y/n] y
Cannot find device "network"
Do you want to pull the latest images? [Y/n] n
Do you want to install STN Daemon? [Y/n] n
Configuration of the node finished successfully.
```

### 手动配置VPP

* 加载PCI驱动

  

``` shell
  modprobe uio_pci_generic
  ```

* 查看并配置网卡

  

``` shell
  lshw -class network -businfo
  ```

  ens192的PCI地址为 0000:0b:00.0。

  

``` shell
  ip link set ens192 down
  ```

  在/etc/vpp/contiv-vswitch.conf中修改：

  

``` json
  dpdk {
      dev 0000:0b:00.0
  }
```

### 初始化master node

参考：

* 参数：<https://kubernetes.io/zh/docs/reference/setup-tools/kubeadm/kubeadm-init/>
* 基本配置：<https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#初始化控制平面节点>  
* Contiv-VPP: <https://fd.io/docs/vpp/master/usecases/contiv/manual_install#initializing-your-master>
* 镜像：<https://sjtug.org/post/mirror-help/gcr-io/>

``` shell
  kubeadm init \
  --token-ttl 0 \
  --pod-network-cidr=10.1.0.0/16 \
  --image-repository k8s-gcr-io.mirrors.sjtug.sjtu.edu.cn \
  --apiserver-advertise-address=192.168.23.128 \
  --control-plane-endpoint=192.168.99.129 \
  --kubernetes-version 1.17.17
```

输出：

``` shell
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.1.10.72:6443 --token el5fc5.f0q358tcajott66s \
    --discovery-token-ca-cert-hash sha256:6a323cb6d7cf51849fbb7e769633e6b0ab159d5c1a33c6f9ee7eb860e05bea0b
```

初始化后需要设置.kube文件夹（普通用户）或添加环境变量（root），详见初始化log末尾。

* 查看启动的pod——kube-system的状态

  

``` shell
root@ubuntu:~# kubectl get pods -n kube-system -o wide
NAME                             READY   STATUS    RESTARTS   AGE     IP           NODE     NOMINATED NODE   READINESS GATES
coredns-74ff55c5b-fvdqx          0/1     Pending   0          2m59s   <none>       <none>   <none>           <none>
coredns-74ff55c5b-v2xvr          0/1     Pending   0          2m59s   <none>       <none>   <none>           <none>
etcd-ubuntu                      1/1     Running   0          3m18s   10.1.10.72   ubuntu   <none>           <none>
kube-apiserver-ubuntu            1/1     Running   0          3m18s   10.1.10.72   ubuntu   <none>           <none>
kube-controller-manager-ubuntu   1/1     Running   0          3m18s   10.1.10.72   ubuntu   <none>           <none>
kube-proxy-lvcq7                 1/1     Running   0          3m      10.1.10.72   ubuntu   <none>           <none>
kube-scheduler-ubuntu            1/1     Running   0          3m18s   10.1.10.72   ubuntu   <none>           <none>
```

  coredns一直pending是因为CNI还没有配置好。

## 配置集群网络

参考： <https://fd.io/docs/vpp/master/usecases/contiv/manual_install#installing-the-contiv-vpp-pod-network>

修改 `vpp/k8s/contiv-vpp.yaml` :

参考： <https://github.com/contiv/vpp/blob/master/docs/arm64/MANUAL_INSTALL_CAVIUM.md#using-kubernetes-110-and-above>

在第544行修改为：(vim内输入544gg)

``` yaml
resources:
  limits:
    hugepages-1Gi: 2Gi
    memory: 2Gi
```

参考：<https://github.com/contiv/vpp/blob/master/docs/setup/SINGLE_NIC_SETUP.md#global-configuration>

单网卡：在第24行之后添加

``` yaml
stealFirstNIC: True
```

``` shell
kubectl apply -f vpp/k8s/contiv-vpp.yaml

```

### 配置worker node(65)

* 和master一样安装kubernetes组件

  用master的初始化log最后的命令加入集群

``` shell
  root@ubuntu:~# kubeadm join 192.168.99.129:6443 --token wk3wwj.ea59d9mwzg5t74r9 \
>         --discovery-token-ca-cert-hash sha256:3b5e30196b619c34e197035628cf62f00acf992dff9865bbbaf5767c4fcf5387
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:

* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

* 在master处给节点添加worker label：

  

``` shell
  kubectl label node ubuntu16 node-role.kubernetes.io/worker=worker
  ```

* worker node的kubeproxy一直处在container creating状态，查看详细信息

  

``` shell
  kubectl describe pod kube-proxy-4ht98 --namespace=kube-system
  
  Failed to create pod sandbox: open /run/systemd/resolve/resolv.conf: no such file or directory
  ```

  直接将master的resolv.conf文件复制一份，kubeproxy开始running。

## 问题

### coredns 一直 CrashLoopBackOff

1. 尝试使用<https://github.com/coredns/coredns/blob/master/plugin/loop/README.md#troubleshooting-loops-in-kubernetes-clusters>和<https://askubuntu.com/a/1041631>。未果
2. 尝试修改hosts，未果<https://stackoverflow.com/a/55433370>

### 安装Dashboard

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
kubectl apply -f https://raw.githubusercontent.com/rootsongjc/kubernetes-handbook/master/manifests/dashboard-1.7.1/admin-role.yaml
kubectl -n kube-system get secret|grep admin-token
kubectl -n kube-system describe secret admin-token-2bfv6
kubectl proxy
ssh -L 8001:127.0.0.1:8001 a@b
