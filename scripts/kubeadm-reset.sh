kubeadm reset -f
# clean CNI configuration
rm -rf /etc/cni/net.d
iptables --flush
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X