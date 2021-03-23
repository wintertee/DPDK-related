从f-stack中安装：
```
wget https://github.com/F-Stack/f-stack/archive/refs/tags/v1.21.tar.gz
tar xzf v1.21.tar.gz
rm v1.21.tar.gz
```

安装pkt-config：
```
sudo apt install -y pkg-config python3-pip
```

安装meson和ninja：
```
pip3 install meson ninja
echo "export PATH=$PATH:~/.local/bin" >> ~/.bashrc
source ~/.bashrc
```
安装dpdk：
```
cd dpdk
meson -Dexamples=all -Denable_kmods=true build
```

输出
```
Message:                                                                                                                =================
Libraries Enabled                                                                                                       =================
kvargs, eal, ring, mempool, mbuf, net, meter, ethdev,pci, cmdline, metrics, hash, timer, acl, bbdev bitratestats,cfgfile, compressdev, cryptodev, distributor, efd, eventdev, gro, gso,ip_frag, jobstats, kni, latencystats, lpm, member, power, pdump,rawdev, rcu, rib, reorder, sched, security, stack, vhost,ipsec, fib, port, table, pipeline, flow_classify, pf,

Message:
===============
Drivers Enabled
===============
common:
    cpt, dpaax, octeontx, octeontx2,
bus:
    dpaa, fslmc, ifpga, pci, vdev, vmbus,
mempool:
    bucket, dpaa, dpaa2, octeontx, octeontx2, ring, stack,
net:
    af_packet, ark, atlantic, avp, axgbe, bond, bnxt, cxgbe,
    dpaa, dpaa2, e1000, ena, enetc, enic, failsafe, fm10k,
    i40e, hinic, hns3, iavf, ice, ifc, ixgbe, kni,
    liquidio, memif, netvsc, nfp, null, octeontx, octeontx2, pfe,
    qede, ring, sfc, softnic, tap, thunderx, vdev_netvsc, vhost,
    virtio, vmxnet3,
raw:
    dpaa2_cmdif, dpaa2_qdma, ioat, ntb, octeontx2_dma, skeleton,
crypto:
    caam_jr, dpaa_sec, dpaa2_sec, nitrox, null_crypto, octeontx_crypto, octeontx2_crypto, crypto_scheduler,
    virtio_crypto,
compress:
    octeontx_compress, qat,
event:
    dpaa, dpaa2, octeontx2, opdl, skeleton, sw, dsw, octeontx,

baseband:
    null, turbo_sw, fpga_lte_fec,                                               

Message:
=================
Content Skipped                                                                                                         =================

libs:
        telemetry:      missing dependency "jansson"

drivers:
        common/mvep:    missing dependency, "libmusdk"
        net/af_xdp:     missing dependency, "libbpf"
        net/bnx2x:      missing dependency, "zlib"
        net/ipn3ke:     missing dependency, "libfdt"
        net/mlx4:       missing dependency, "ibverbs"
        net/mlx5:       missing dependency, "ibverbs"
        net/mvneta:     missing dependency, "libmusdk"
        net/mvpp2:      missing dependency, "libmusdk"
        net/nfb:        missing dependency, "libnfb"
        net/pcap:       missing dependency, "libpcap"
        net/szedata2:   missing dependency, "libsze2"
        raw/ifpga:      missing dependency, "libfdt"
        crypto/aesni_gcm:       missing dependency, "libIPSec_MB"
        crypto/aesni_mb:        missing dependency, "libIPSec_MB"
        crypto/ccp:     missing dependency, "libcrypto"
        crypto/kasumi:  missing dependency, "libsso_kasumi"
        crypto/mvsam:   missing dependency, "libmusdk"
        crypto/openssl: missing dependency, "libcrypto"
        crypto/snow3g:  missing dependency, "libsso_snow3g"
        crypto/zuc:     missing dependency, "libsso_zuc"
        compress/isal:  missing dependency, "libisal"
        compress/zlib:  missing dependency, "zlib"


Build targets in project: 790
```

```
cd build
ninja
ninja install
ldconfig
```

检查pkt-config已成功配置：
```
pkg-config --modversion libdpdk
```
