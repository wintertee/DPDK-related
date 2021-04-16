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
apt-get install -y kubelet kubeadm kubectl
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
git clone https://gitclone.com/github.com/contiv/vpp.git
```

``` shell
root@ubuntu:~/vpp/k8s# ./setup-node.sh
#########################################
#   Contiv - VPP                        #
#########################################
Do you want to setup multinode cluster? [Y/n] y
PCI UIO driver is loaded
The following network devices were found
1) ens33 0000:02:01.0
2) ens38 0000:02:06.0
Select interface for node interconnect [1-2]:2
Device 'ens38' must be shutdown, do you want to proceed? [Y/n] y

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
   dev 0000:02:06.0
}
socksvr {
   default
}
statseg {
   default
}

File /etc/vpp/contiv-vswitch.conf will be modified, do you want to proceed? [Y/n] y
./setup-node.sh: line 120: /etc/vpp/contiv-vswitch.conf: No such file or directory
Do you want to pull the latest images? [Y/n] y
Using Images Tag: latest
latest: Pulling from contivvpp/vswitch
f08d8e2a3ba1: Pull complete
3baa9cb2483b: Pull complete
94e5ff4c0b15: Pull complete
1860925334f9: Pull complete
a72a2355abbf: Pull complete
becbfe3b8eb0: Pull complete
1d0714146e72: Pull complete
8776da26c5cf: Pull complete
e0a6271abe8f: Pull complete
167a9eaa86b1: Pull complete
00df78f9d945: Pull complete
b271b597db01: Pull complete
Digest: sha256:6187ab0a9b192143416be956fef86bd5a2a9affffc7f024809fbeb8d743d5c60
Status: Downloaded newer image for contivvpp/vswitch:latest
docker.io/contivvpp/vswitch:latest
latest: Pulling from contivvpp/ksr
Digest: sha256:6fca50c3ca019c4d232f1e787b85740a4ab5ec7d27c1e1be58a85ffd1af9532e
Status: Image is up to date for contivvpp/ksr:latest
docker.io/contivvpp/ksr:latest
latest: Pulling from contivvpp/cni
486039affc0a: Already exists
0888d65d759f: Pull complete
Digest: sha256:8d5d22941b90cfca2260179fc3936117130881cd3c36a1eb155c204fd5c936ec
Status: Downloaded newer image for contivvpp/cni:latest
docker.io/contivvpp/cni:latest
latest: Pulling from contivvpp/stn
Digest: sha256:fd50f00124f34fe647943e4662b08ffe3c9d990f57a76f5c8f5676fb33ea1f92
Status: Image is up to date for contivvpp/stn:latest
docker.io/contivvpp/stn:latest
latest: Pulling from contivvpp/crd
Digest: sha256:acd78f7159b940d30ab88535a9958bf6ccd8452ffce3f91939b29b5217c1179a
Status: Image is up to date for contivvpp/crd:latest
docker.io/contivvpp/crd:latest
latest: Pulling from contivvpp/ui
486039affc0a: Already exists
bb78e8fe28e6: Pull complete
9097a2ed16fb: Pull complete
a053d0561ba7: Pull complete
0250d87d9a8b: Pull complete
Digest: sha256:15686861cde827e267d1d2a18915216ffbf499d9f27c62e4f2ef9907e0245c51
Status: Downloaded newer image for contivvpp/ui:latest
docker.io/contivvpp/ui:latest
Do you want to install STN Daemon? [Y/n] y
Installing Contiv STN daemon.
Starting contiv-stn Docker container:
fb5dd64b96fc430a26a4734778bf095fd7078fbfea715ddbbe1ceade693c1700
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
  kubeadm init --token-ttl 0 --pod-network-cidr=10.1.0.0/16 --image-repository k8s-gcr-io.mirrors.sjtug.sjtu.edu.cn --apiserver-advertise-address=192.168.23.128 --control-plane-endpoint=192.168.99.129
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

kubeadm join 192.168.42.128:6443 --token 3baouc.a4ijowt668u3lwc0 \
        --discovery-token-ca-cert-hash sha256:fc3e536c2dfe5ec39213f7be4dcbf8dac205fd277f6ab73832314df65012ed21

```

初始化后需要设置.kube文件夹（普通用户）或添加环境变量（root），详见初始化log末尾。

* 查看启动的pod——kube-system的状态

  

``` shell
root@ubuntu:~# kubectl get pods -n kube-system -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP               NODE     NOMINATED NODE   READINESS GATES
coredns-5f97648f5b-fvn2t         0/1     Pending   0          46s   <none>           <none>   <none>           <none>
coredns-5f97648f5b-kwdtg         0/1     Pending   0          46s   <none>           <none>   <none>           <none>
etcd-ubuntu                      1/1     Running   0          56s   192.168.42.134   ubuntu   <none>           <none>
kube-apiserver-ubuntu            1/1     Running   0          56s   192.168.42.134   ubuntu   <none>           <none>
kube-controller-manager-ubuntu   1/1     Running   0          56s   192.168.42.134   ubuntu   <none>           <none>
kube-proxy-gvm5h                 1/1     Running   0          46s   192.168.42.134   ubuntu   <none>           <none>
kube-scheduler-ubuntu            1/1     Running   0          56s   192.168.42.134   ubuntu   <none>           <none>
```

  coredns一直pending是因为CNI还没有配置好。

## 配置集群网络

参考： <https://fd.io/docs/vpp/master/usecases/contiv/manual_install#installing-the-contiv-vpp-pod-network>

修改 `vpp/k8s/contiv-vpp.yaml` :

参考： <https://github.com/contiv/vpp/blob/master/docs/arm64/MANUAL_INSTALL_CAVIUM.md#using-kubernetes-110-and-above>

在第421行修改为：(vim内输入421gg)

``` yaml
          resources:
            limits:
              hugepages-1Gi: 2Gi
              memory: 2Gi
```

参考：<https://github.com/contiv/vpp/blob/master/docs/setup/SINGLE_NIC_SETUP.md#global-configuration>

单网卡：在第24行之后添加
```yaml
stealFirstNIC: True
```

```shell
kubectl apply -f ./contiv-vpp.yaml

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
