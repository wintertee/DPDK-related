# 部署k8s集群和Contiv-VPP CNI
参考https://fd.io/docs/vpp/latest/usecases/contiv/

## 环境

- Kubernetes 1.20.5
- Contiv 3.4.2

## 搭建k8s集群 

### 配置master node(72)

- 加载PCI驱动

  ```shell
  modprobe uio_pci_generic
  ```

- 查看并配置网卡

  ```shell
  lshw -class network -businfo
  ```

  ens192的PCI地址为 0000:0b:00.0。

  ```shell
  ip link set ens192 down
  ```

  在/etc/vpp/contiv-vswitch.conf中修改：

  ```json
  dpdk {
      dev 0000:0b:00.0
  }
  ```

- 安装kubelet，kubeadm，kubectl

  ```shell
  apt-get update && apt-get install -y apt-transport-https
  curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
  cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
  deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
  EOF
  
  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
  ```

- 关闭swap

  ```shell
  swapoff -a
  ```

- 修改docker驱动

  ```shell
  mkdir /etc/docker/daemon.json
  ```

  加入以下内容：
  
  > 参考 <https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker>

  ```json
  {
   "exec-opts":["native.cgroupdriver=systemd"]
  }
  ```

  重启docker

  ```shell
  service docker restart
  ```

- 从阿里云拉取需要的镜像并tag

  ```shell
  images=(
      kube-apiserver:v1.20.5
      kube-controller-manager:v1.20.5
      kube-scheduler:v1.20.5
      kube-proxy:v1.20.5
      pause:3.2
      etcd:3.4.13-0
      coredns:1.7.0
  )
  for imageName in ${images[@]} ; do
      docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName}
      docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName} k8s.gcr.io/${imageName}
      docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/${imageName}
  done
  ```

- 初始化master node

  ```shell
  kubeadm init --token-ttl 0 --pod-network-cidr=10.1.0.0/16
  ```

  如果失败，重新初始化之前kubeadm reset

  初始化后需要设置.kube文件夹（普通用户）或添加环境变量（root），详见初始化log末尾。

  ```shell
  export KUBECONFIG=/etc/kubernetes/admin.conf
  ```

- 查看启动的pod——kube-system的状态

  ```shell
  kubectl get pods -n kube-system -o wide
  ```

  coredns一直pending是因为CNI还没有配置好。

### 配置worker node(65)

- 和master一样安装kubernetes组件

  用master的初始化log最后的命令加入集群

- 在master处给节点添加worker label：

  ```shell
  kubectl label node ubuntu16 node-role.kubernetes.io/worker=worker
  ```

- worker node的kubeproxy一直处在container creating状态，查看详细信息

  ```shell
  kubectl describe pod kube-proxy-4ht98 --namespace=kube-system
  
  Failed to create pod sandbox: open /run/systemd/resolve/resolv.conf: no such file or directory
  ```

  直接将master的resolv.conf文件复制一份，kubeproxy开始running。

## 部署Contiv-VPP

参考：<https://fd.io/docs/vpp/master/usecases/contiv/networking>

```shell
wget https://raw.githubusercontent.com/contiv/vpp/master/k8s/contiv-vpp.yaml
kubectl apply -f ./contiv-vpp.yaml
```

目前不成功，contiv-vswitch的状态是CrashLoopBackOff

查看log

```shell
kubectl logs contiv-vswitch-lmjbb -n kube-system

time="2021-04-09 08:20:16.99284" level=debug msg="connection to VPP established (took 6ms)" loc="govppmux/plugin_impl_govppmux.go(146)" logger=govpp
time="2021-04-09 08:20:16.99315" level=debug msg="binapi version 19.04.2 core incompatible (214/362 messages)" loc="logging/log_api.go(37)" logger=defaultLogger
time="2021-04-09 08:20:16.99341" level=debug msg="binapi version 19.08.1 core incompatible (198/384 messages)" loc="logging/log_api.go(37)" logger=defaultLogger
time="2021-04-09 08:20:16.99359" level=debug msg="binapi version 20.01-rc2~11 core incompatible (70/364 messages)" loc="logging/log_api.go(37)" logger=defaultLogger
time="2021-04-09 08:20:16.99370" level=fatal msg="retrieving VPP info failed: no compatible binapi version found" loc="contiv-agent/main.go(304)" logger=defaultLogger
```

重启虚拟机之后解决了

查看集群运行状况

```shell
root@ubuntu:~# kubectl get pods -n kube-system -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
contiv-crd-5j7fk                 1/1     Running   0          20h   10.1.10.72   ubuntu     <none>           <none>
contiv-etcd-0                    1/1     Running   0          20h   10.1.10.72   ubuntu     <none>           <none>
contiv-ksr-pgvmz                 1/1     Running   0          20h   10.1.10.72   ubuntu     <none>           <none>
contiv-vswitch-pvk9x             1/1     Running   0          20h   10.1.10.65   ubuntu16   <none>           <none>
contiv-vswitch-qs9jq             1/1     Running   0          20h   10.1.10.72   ubuntu     <none>           <none>
coredns-74ff55c5b-48txz          1/1     Running   4          21h   10.1.2.3     ubuntu     <none>           <none>
coredns-74ff55c5b-65wx9          1/1     Running   4          21h   10.1.2.2     ubuntu     <none>           <none>
etcd-ubuntu                      1/1     Running   0          21h   10.1.10.72   ubuntu     <none>           <none>
kube-apiserver-ubuntu            1/1     Running   0          21h   10.1.10.72   ubuntu     <none>           <none>
kube-controller-manager-ubuntu   1/1     Running   1          21h   10.1.10.72   ubuntu     <none>           <none>
kube-proxy-k6jkk                 1/1     Running   0          21h   10.1.10.72   ubuntu     <none>           <none>
kube-proxy-pf69v                 1/1     Running   0          21h   10.1.10.65   ubuntu16   <none>           <none>
kube-scheduler-ubuntu            1/1     Running   0          21h   10.1.10.72   ubuntu     <none>           <none>
```

VPP failed to grab the NIC ens160. Don't know if it should be configured in /etc/vpp/startup.conf.
