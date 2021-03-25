# 脚本

- [ping.sh](ping.sh) 用于在服务器断开网络连接时自动重启，用于测试host机网卡时在后台运行
- [dpdk-make](dpdk-make/Dockerfile) 是通过Makefile编译DPDK，生成含有DPDK和f-stack的Docker镜像
- [dpdk-meson](dpdk-meson/Dockerfile) 是通过meson+ninja编译DPDK，生成**仅含有DPDK**的Docker镜像
  - [ ] 添加编译f-stack的命令
