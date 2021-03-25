FROM ubuntu:18.04
WORKDIR /root
RUN apt-get update && \
    apt-get -y install libnuma-dev libssl-dev \
                       vim wget\
                       libpcap-dev python3-pip pkg-config wget \
                       linux-headers-$(uname -r) gawk && \
    pip3 install meson ninja && \
    wget -c --retry-connrefused --tries=5 --timeout=5 \
         https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz && \
    tar xzf v1.21.tar.gz && \
    rm v1.21.tar.gz && \
    cd f-stack-1.21/dpdk/ && \
    meson -Dexamples=all -Denable_kmods=true build && \
    ninja -C build && \
    ninja install
    
