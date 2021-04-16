# 部署k8s集群和Contiv-VPP CNI

参考https://fd.io/docs/vpp/latest/usecases/contiv/

## 环境

* Kubernetes 1.20.5
* Contiv 3.4.2

#

## 部署Contiv-VPP

参考：<https://fd.io/docs/vpp/master/usecases/contiv/networking>

``` shell
wget https://raw.githubusercontent.com/contiv/vpp/master/k8s/contiv-vpp.yaml
kubectl apply -f ./contiv-vpp.yaml
```

目前不成功，contiv-vswitch的状态是CrashLoopBackOff

查看log

``` shell
kubectl logs contiv-vswitch-lmjbb -n kube-system

time="2021-04-09 08:20:16.99284" level=debug msg="connection to VPP established (took 6ms)" loc="govppmux/plugin_impl_govppmux.go(146)" logger=govpp
time="2021-04-09 08:20:16.99315" level=debug msg="binapi version 19.04.2 core incompatible (214/362 messages)" loc="logging/log_api.go(37)" logger=defaultLogger
time="2021-04-09 08:20:16.99341" level=debug msg="binapi version 19.08.1 core incompatible (198/384 messages)" loc="logging/log_api.go(37)" logger=defaultLogger
time="2021-04-09 08:20:16.99359" level=debug msg="binapi version 20.01-rc2~11 core incompatible (70/364 messages)" loc="logging/log_api.go(37)" logger=defaultLogger
time="2021-04-09 08:20:16.99370" level=fatal msg="retrieving VPP info failed: no compatible binapi version found" loc="contiv-agent/main.go(304)" logger=defaultLogger
```

重启虚拟机之后解决了

查看集群运行状况

``` shell
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
