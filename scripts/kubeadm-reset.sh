kubeadm reset -f
# clean CNI configuration
rm -rf /etc/cni/net.d
# clean vpp configuration
rm -rf /etc/vpp