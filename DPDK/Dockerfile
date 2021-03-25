FROM ubuntu:18.04
RUN apt-get update && \
    apt-get -y libnuma-dev libssl-dev \
               vim wget\
               libpcap-dev python3-pip pkg-config wget&& \
    \\ apt install linux-headers-$(uname -r)
    pip3 install meson ninja
    cd /root && \
    wget -c --retry-connrefused --tries=5 --timeout=5 \
         https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz && \
    tar xzf v1.21.tar.gz && \
    rm v1.21.tar.gz && \
    cd f-stack-1.21/dpdk/ && \
    meson -Dexamples=all -Denable_kmods=true build && \
    ninja -C build && \
    
