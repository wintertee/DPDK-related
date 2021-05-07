# 安装VPP

使用contiv-vpp时无需此步骤。

``` shell
curl -L https://packagecloud.io/fdio/release/gpgkey | sudo apt-key add -
sudo add-apt-repository "deb [trusted=yes] https://packagecloud.io/fdio/release/ubuntu bionic main" 
sudo apt-get install -y vpp vpp-plugin-core vpp-plugin-dpdk
```
