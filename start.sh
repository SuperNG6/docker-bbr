#!/bin/bash

/sbin/ip tuntap add dev tap0 mode tap
/sbin/ip addr add 10.0.0.1/24 dev tap0
/sbin/ip link set dev tap0 up

# 使用 lkl-hijack 设置默认路由
/usr/local/bin/lkl-hijack.sh /sbin/ip route add default via 10.0.0.2

# 创建 HAProxy 配置文件
cat <<EOF > /usr/local/etc/haproxy/haproxy.cfg
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
EOF

# 为每个前端端口和后端目标创建配置
IFS=', ' read -r -a frontend_ports <<< "$FRONTEND_PORTS"
IFS=', ' read -r -a backend_targets <<< "$BACKEND_TARGETS"
for index in "${!frontend_ports[@]}"
do
    cat <<EOF >> /usr/local/etc/haproxy/haproxy.cfg
frontend ft_tcp_${frontend_ports[index]}
    bind *:${frontend_ports[index]}
    default_backend bk_tcp_${frontend_ports[index]}

backend bk_tcp_${frontend_ports[index]}
    server backend1 ${backend_targets[index]}
EOF
done

# 启动 HAProxy
/usr/sbin/haproxy -f /usr/local/etc/haproxy/haproxy.cfg
