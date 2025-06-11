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
echo "2) Web 目录验证 (webroot)"
echo "3) DNS 验证 (域名解析)"
echo "4) Cloudflare API 验证"
read -p "$(green_text '输入选择(1/2/3/4): ')" METHOD_CHOICE

if [ "$METHOD_CHOICE" -eq 1 ]; then
    METHOD="--standalone $IP_MODE"
elif [ "$METHOD_CHOICE" -eq 2 ]; then
    read -p "$(green_text '请输入 Web 根目录路径: ')" WEBROOT_PATH
    if [ ! -d "$WEBROOT_PATH" ]; then
        green_text "指定的 Web 根目录不存在，退出。"
        exit 1
    fi
    METHOD="-w $WEBROOT_PATH"
elif [ "$METHOD_CHOICE" -eq 3 ]; then
    green_text "请使用以下信息配置 DNS 解析:"
    green_text "1. 登录您的 DNS 提供商管理面板。"
    green_text "2. 添加一条 TXT 记录，主机名为 _acme-challenge.$DOMAIN。"
    green_text "3. 值将由命令运行后提供。请运行以下命令获取值:"
    echo "/root/.acme.sh/acme.sh --issue -d $DOMAIN --dns --debug"
    exit 0
elif [ "$METHOD_CHOICE" -eq 4 ]; then
    green_text "使用 Cloudflare API 验证，请确保已配置以下环境变量:"
    green_text "1. CF_Token: Cloudflare API 密钥。"
    green_text "2. CF_Account_ID: Cloudflare 帐号 ID。"
    green_text "请在运行脚本前确保这两个变量正确设置。"
    METHOD="--dns dns_cf"
else
    green_text "无效选择，退出。"
    exit 1
fi

# 定义证书安装目录
CERT_DIR="/root/cert/$DOMAIN"
mkdir -p "$CERT_DIR"

# 使用 acme.sh 生成证书
green_text "开始申请证书..."
/root/.acme.sh/acme.sh --issue -d "$DOMAIN" $METHOD

if [ $? -ne 0 ]; then
    green_text "证书申请失败，请检查错误信息。"
    exit 1
fi

# 安装证书到指定目录
green_text "安装证书到目录: $CERT_DIR"
/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
--key-file "$CERT_DIR/privkey.pem" \
--fullchain-file "$CERT_DIR/fullchain.pem"

if [ $? -eq 0 ]; then
    green_text "证书申请和安装成功！"
    green_text "证书路径: $CERT_DIR/fullchain.pem"
    green_text "私钥路径: $CERT_DIR/privkey.pem"
else
    green_text "证书安装失败，请检查错误信息。"
    exit 1
fi

# 提示用户完成
green_text "操作完成。"
