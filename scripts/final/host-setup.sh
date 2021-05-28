apt-get update && \
apt-get -y install build-essential python3-pip pkg-config \
wget net-tools \
linux-headers-$(uname -r) \
libnuma-dev libssl-dev libpcap-dev gawk \
autoconf libtool \

pip3 install meson ninja && \

# download source code:
wget -c --retry-connrefused --tries=5 --timeout=5 \
# https://github.com/F-Stack/f-stack/archive/refs/heads/dev.zip && \
https://gh.api.99988866.xyz/https://github.com/F-Stack/f-stack/archive/refs/heads/dev.zip && \
unzip dev.zip && \
rm dev.zip && \
# build dpdk:
cd f-stack-dev/dpdk/ && \
meson -Dexamples=all -Denable_kmods=true build && \
ninja -C build && \
ninja -C build install && \
# build f-stack:
cd ../lib/ && \
export FF_PATH=/root/f-stack-dev && \
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig && \
make -j8 && \
make install

# download ovs
cd ~ && \
wget -c --retry-connrefused --tries=5 --timeout=5 \
# https://github.com/openvswitch/ovs/archive/refs/tags/v2.15.0.zip
https://gh.api.99988866.xyz/https://github.com/openvswitch/ovs/archive/refs/tags/v2.15.0.zip
unzip v2.15.0.zip && \
rm v2.15.0.zip && \

# install ovs
cd ovs-2.15.0/ && \
./boot.sh
./configure --with-dpdk CFLAGS="-Ofast -msse4.2 -mpopcnt -mavx"
make -j8
make install

# download docker
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common
curl -fsSL https://mirror.sjtu.edu.cn/docker-ce/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://mirror.sjtu.edu.cn/docker-ce/linux/ubuntu/  $(lsb_release -cs)  stable" 
apt-get install -y docker-ce docker-ce-cli containerd.io

