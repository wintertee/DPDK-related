FROM ubuntu:18.04
WORKDIR /root/
COPY . /root/f-stack-dev
RUN apt-get update && \
    apt-get -y install build-essential python3-pip pkg-config wget \
    libnuma-dev libssl-dev libpcap-dev gawk && \
    pip3 install meson ninja && \
    # build dpdk:
    cd f-stack-dev/dpdk/ && \
    ninja -C build install && \
    # build f-stack:
    cd ../lib/ && \
    export FF_PATH=/root/f-stack-dev && \
    export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig && \
    make install