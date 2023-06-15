#!/bin/bash

set -e

# 检查命令是否存在
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 command not found. Please install it and try again."
        exit 1
    fi
}

# 验证参数
validate_parameters() {
    if [ -z "$FRONTEND_PORTS" ]; then
        echo "Error: FRONTEND_PORTS parameter is missing."
        exit 1
    fi

    if [ -z "$BACKEND_TARGETS" ]; then
        echo "Error: BACKEND_TARGETS parameter is missing."
        exit 1
    fi

    IFS=',' read -r -a frontend_ports <<< "$FRONTEND_PORTS"
    IFS=',' read -r -a backend_targets <<< "$BACKEND_TARGETS"

    if [ ${#frontend_ports[@]} -ne ${#backend_targets[@]} ]; then
        echo "Error: FRONTEND_PORTS and BACKEND_TARGETS arrays must have the same length."
        exit 1
    fi
}

# 创建 TAP 设备
create_tap_device() {
    echo "Creating TAP device..."
    /sbin/ip tuntap add dev tap0 mode tap
    /sbin/ip addr add 10.0.0.1/24 dev tap0
    /sbin/ip link set dev tap0 up
}

# 使用 lkl-hijack 设置默认路由
setup_default_route() {
    echo "Setting up default route..."
    /usr/local/bin/lkl-hijack.sh /sbin/ip route add default via 10.0.0.2
}

# 创建 HAProxy 配置文件
create_haproxy_config() {
    echo "Creating HAProxy configuration file..."
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
}

# 为每个前端端口和后端目标创建配置
create_backend_configs() {
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
}

# 启动 HAProxy
start_haproxy() {
    echo "Starting HAProxy..."
    /usr/sbin/haproxy -f /usr/local/etc/haproxy/haproxy.cfg
}

# 主函数
main() {
    # 检查命令是否存在
    check_command ip
    check_command tuntap
    check_command lkl-hijack.sh
    check_command haproxy

    # 验证参数
    validate_parameters

    # 创建 TAP 设备
    create_tap_device

    # 使用 lkl-hijack 设置默认路由
    setup_default_route

    # 创建 HAProxy 配置文件
    create_haproxy_config

    # 为每个前端端口和后端目标创建配置
    create_backend_configs

    # 启动 HAProxy
    start_haproxy
}

# 运行主函数
main
