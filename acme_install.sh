#!/bin/bash

# 输出绿色文字的函数
green_text() {
    echo -e "\033[32m$1\033[0m"
}

# 检查并安装 acme.sh
if [ ! -f /root/.acme.sh/acme.sh ]; then
    green_text "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | sh
    source ~/.bashrc
else
    green_text "acme.sh 已安装，跳过安装步骤。"
fi

# 提示用户选择网络协议版本
green_text "请选择网络协议版本:"
echo "1) IPv4"
echo "2) IPv6"
read -p "$(green_text '输入选择(1/2): ')" PROTOCOL_CHOICE

if [ "$PROTOCOL_CHOICE" -eq 1 ]; then
    IP_MODE="--listen-v4"
elif [ "$PROTOCOL_CHOICE" -eq 2 ]; then
    IP_MODE="--listen-v6"
else
    green_text "无效选择，退出。"
    exit 1
fi

# 提示用户输入域名
read -p "$(green_text '请输入要生成证书的域名: ')" DOMAIN

# 提示用户选择验证方式
green_text "请选择验证方式:"
echo "1) 临时 HTTP (standalone)"
echo "2) We
