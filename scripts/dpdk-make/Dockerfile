FROM ubuntu:18.04
WORKDIR /root
RUN apt-get update && \
# for f-stack:
    apt-get -y install \
    libnuma-dev libssl-dev libpcap-dev gawk \
# utils:
    vim wget build-essential\
# to compile DPDK kernel module:
    linux-headers-$(uname -r) gawk && \
# download source code:
    wget -c --retry-connrefused --tries=5 --timeout=5 \
#       https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz && \
        https://gh.api.99988866.xyz/https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz && \
    tar xzf v1.21.tar.gz && \
    rm v1.21.tar.gz && \
# build dpdk:
    cd f-stack-1.21/dpdk/ && \
    export RTE_SDK=/root/f-stack-1.21/dpdk && \
    export RTE_TARGET=x86_64-native-linuxapp-gcc && \
    make defconfig O=x86_64-native-linuxapp-gcc && \
    make -j8 O=x86_64-native-linuxapp-gcc && \
# build f-stack:
    export FF_PATH=/root/f-stack-1.21/ && \
    export FF_DPDK=/root/f-stack-1.21/dpdk/x86_64-native-linuxapp-gcc/ && \
    cd /root/f-stack-1.21/lib/ && \
    make -j8 && \
    make install