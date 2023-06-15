# 第一阶段：构建阶段
FROM debian:11 as build

RUN apt-get update && apt-get install -y \
    build-essential \
    coreutils \
    libfuse-dev libarchive-dev xfsprogs \
    libmnl-dev \
    libnuma-dev \
    libcap-dev \
    libaio-dev \
    librdmacm-dev \
    libnet1-dev \
    libpcap0.8-dev \
    gcc \
    make \
    autoconf \
    automake \
    libtool \
    flex \
    bison \
    git \
    iptables \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libprotobuf-dev \
    libncurses-dev \
    libreadline-dev \
    libsqlite3-dev \
    libxml2-dev


WORKDIR /usr/src
RUN git clone https://github.com/lkl/linux.git

WORKDIR /usr/src/linux/tools/lkl
RUN make && make install

# 第二阶段：运行阶段
FROM debian:11-slim

# 安装需要的依赖项，并清理 apt 缓存
RUN apt-get update && apt-get install -y \
    iptables \
    libnet1 \
    libpcap0.8 \
    haproxy && \
    rm -rf /var/lib/apt/lists/*

# 从构建阶段复制 LKL
COPY --from=build /usr/local/bin/lkl-hijack.sh /usr/local/bin/lkl-hijack.sh
COPY --from=build /usr/local/lib/liblkl.so /usr/local/lib/liblkl.so
COPY --from=build /usr/local/lib/liblkl-hijack.so /usr/local/lib/liblkl-hijack.so

# 设置 hijack 脚本和参数
ENV LD_PRELOAD="/usr/local/lib/liblkl-hijack.so"
ENV LKL_HIJACK_NET_QDISC="root|fq"
ENV LKL_HIJACK_SYSCTL="net.ipv4.tcp_congestion_control=bbr"
ENV LKL_HIJACK_NET_IFTYPE="tap"
ENV LKL_HIJACK_NET_IFPARAMS="tap0"
ENV LKL_HIJACK_NET_IP="10.0.0.2"
ENV LKL_HIJACK_NET_NETMASK_LEN="24"
ENV LKL_HIJACK_NET_GATEWAY="10.0.0.1"
ENV LKL_HIJACK_OFFLOAD="0x8883"
ENV LKL_HIJACK_DEBUG="0"

ENV FRONTEND_PORTS=8080,8081
ENV BACKEND_TARGETS=10.0.0.2:80,10.0.0.2:443

# 启动脚本
COPY start.sh /start.sh
RUN chmod +x /start.sh


CMD ["/start.sh"]
