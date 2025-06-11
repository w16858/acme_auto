#!/bin/bash

# 检查并安装 acme.sh
if ! command -v acme.sh &>/dev/null; then
    echo "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | sh
    source ~/.bashrc
else
    echo "acme.sh 已安装，跳过安装步骤。"
fi

# 提示用户选择网络协议版本
echo "请选择网络协议版本:"
echo "1) IPv4"
echo "2) IPv6"
read -p "输入选择(1/2): " PROTOCOL_CHOICE

if [ "$PROTOCOL_CHOICE" -eq 1 ]; then
    IP_MODE="--listen-v4"
elif [ "$PROTOCOL_CHOICE" -eq 2 ]; then
    IP_MODE="--listen-v6"
else
    echo "无效选择，退出。"
    exit 1
fi

# 提示用户输入域名
read -p "请输入要生成证书的域名: " DOMAIN

# 提示用户选择验证方式
echo "请选择验证方式:"
echo "1) 临时 HTTP (standalone)"
echo "2) Web 目录验证 (webroot)"
echo "3) DNS 验证 (域名解析)"
echo "4) Cloudflare API 验证"
read -p "输入选择(1/2/3/4): " METHOD_CHOICE

if [ "$METHOD_CHOICE" -eq 1 ]; then
    METHOD="--standalone $IP_MODE"
elif [ "$METHOD_CHOICE" -eq 2 ]; then
    read -p "请输入 Web 根目录路径: " WEBROOT_PATH
    if [ ! -d "$WEBROOT_PATH" ]; then
        echo "指定的 Web 根目录不存在，退出。"
        exit 1
    fi
    METHOD="-w $WEBROOT_PATH"
elif [ "$METHOD_CHOICE" -eq 3 ]; then
    echo "请确保 DNS 验证支持您的 DNS 提供商，参考: https://github.com/acmesh-official/acme.sh/wiki/dnsapi"
    read -p "请输入 DNS 提供商的配置命令 (如 --dns dns_ali): " DNS_PROVIDER
    METHOD="$DNS_PROVIDER"
elif [ "$METHOD_CHOICE" -eq 4 ]; then
    echo "使用 Cloudflare API 验证，请确保环境变量 CF_Token 和 CF_Account_ID 已配置。"
    METHOD="--dns dns_cf"
else
    echo "无效选择，退出。"
    exit 1
fi

# 定义证书安装目录
CERT_DIR="/root/cert/$DOMAIN"
mkdir -p "$CERT_DIR"

# 使用 acme.sh 生成证书
echo "开始申请证书..."
/root/.acme.sh/acme.sh --issue -d "$DOMAIN" $METHOD

if [ $? -ne 0 ]; then
    echo "证书申请失败，请检查错误信息。"
    exit 1
fi

# 安装证书到指定目录
echo "安装证书到目录: $CERT_DIR"
acme.sh --install-cert -d "$DOMAIN" \
--key-file "$CERT_DIR/privkey.pem" \
--fullchain-file "$CERT_DIR/fullchain.pem"

if [ $? -eq 0 ]; then
    echo "证书申请和安装成功！"
    echo "证书路径: $CERT_DIR/fullchain.pem"
    echo "私钥路径: $CERT_DIR/privkey.pem"
else
    echo "证书安装失败，请检查错误信息。"
    exit 1
fi

# 提示用户完成
echo "操作完成。"
