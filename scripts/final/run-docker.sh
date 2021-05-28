docker run --privileged --name fstack-run \
-v /mnt/huge:/mnt/huge \
-v /usr/local/var/run/openvswitch:/var/run/openvswitch \
fstack-run