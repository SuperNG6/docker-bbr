# 第一阶段：构建阶段
FROM debian:latest as build

RUN apt-get update && apt-get install -y \
    gcc \
    make \
    autoconf \
    automake \
    libtool \
    git \
    iptables \
    libnet1-dev \
    libpcap0.8-dev 

WORKDIR /usr/src
RUN git clone https://github.com/lkl/linux.git

WORKDIR /usr/src/linux/tools/lkl
RUN make && make install

# 第二阶段：运行阶段
FROM debian:slim

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

# 启动脚本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 设置 hijack 脚本
ENV LD_PRELOAD /usr/local/lib/liblkl-hijack.so

CMD ["/start.sh"]
