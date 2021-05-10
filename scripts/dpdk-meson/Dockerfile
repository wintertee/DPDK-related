FROM ubuntu:18.04
WORKDIR /root
RUN apt-get update && \
    apt-get -y install \
# for f-stack:
    apt-get -y install \
    libnuma-dev libssl-dev libpcap-dev gawk \
# utils:
    vim wget build-essential\
# for DPDK:
   pkg-config \
# to compile DPDK kernel module:
    linux-headers-$(uname -r) && \
# to build DPDK:
    pip3 install meson ninja && \
# download source code:
    wget -c --retry-connrefused --tries=5 --timeout=5 \
#       https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz && \
        https://gh.api.99988866.xyz/https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz && \
    tar xzf v1.21.tar.gz && \
    rm v1.21.tar.gz && \
    cd f-stack-1.21/dpdk/ && \
# build dpdk:
    meson -Dexamples=all -Denable_kmods=true build && \
    ninja -C build && \
    ninja -C build install && \
# build f-stack
    export FF_PATH=/root/f-stack-1.21 && \
    export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig && \
    cd /root/f-stack-1.21/lib/ && \
    make && \
    make install
