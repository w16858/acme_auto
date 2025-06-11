#!/bin/bash

# 输出绿色文字
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

# 提示用户输入域名
green_text "请输入要生成证书的域名: "
read DOMAIN

# 提示用户选择验证方式
green_text "请选择验证方式:"
echo "1) 临时 HTTP 验证 (standalone)"
echo "2) Cloudflare API 验证"
read -p "输入选择 (1/2): " METHOD_CHOICE

if [ "$METHOD_CHOICE" -eq 1 ]; then
    # 自动检测域名解析类型 (A 或 AAAA)
    green_text "正在检查域名解析记录..."
    IPV4=$(dig +short A "$DOMAIN")
    IPV6=$(dig +short AAAA "$DOMAIN")

    if [ -n "$IPV4" ]; then
        IP_MODE="--listen-v4"
        green_text "检测到域名使用 IPv4 (A 记录): $IPV4"
    elif [ -n "$IPV6" ]; then
        IP_MODE="--listen-v6"
        green_text "检测到域名使用 IPv6 (AAAA 记录): $IPV6"
    else
        green_text "未检测到有效的 A 或 AAAA 记录，请先确保域名正确解析后重试。"
        exit 1
    fi

    green_text "请输入临时 HTTP 验证端口（默认80端口）: "
    read HTTP_PORT
    if [ -z "$HTTP_PORT" ]; then
        HTTP_PORT=80
    fi

    METHOD="--standalone $IP_MODE --httpport $HTTP_PORT"

elif [ "$METHOD_CHOICE" -eq 2 ]; then
    # Cloudflare API 验证
    green_text "使用 Cloudflare API 验证，请确保环境变量已配置。"

    # 检查现有的 Cloudflare API 信息
    if [ -f ~/.acme.sh/account.conf ]; then
        CF_TOKEN=$(grep "^export CF_Token" ~/.acme.sh/account.conf | cut -d '"' -f 2)
        CF_ACCOUNT_ID=$(grep "^export CF_Account_ID" ~/.acme.sh/account.conf | cut -d '"' -f 2)
    fi

    # 提示用户输入缺失的信息
    if [ -z "$CF_TOKEN" ]; then
        green_text "未检测到 Cloudflare API Token，请输入:"
        read -p "CF_Token: " CF_TOKEN
        export CF_Token="$CF_TOKEN"
    else
        green_text "已检测到 Cloudflare API Token，跳过输入。"
    fi

    if [ -z "$CF_ACCOUNT_ID" ]; then
        green_text "未检测到 Cloudflare Account ID，请输入:"
        read -p "CF_Account_ID: " CF_ACCOUNT_ID
        export CF_Account_ID="$CF_ACCOUNT_ID"
    else
        green_text "已检测到 Cloudflare Account ID，跳过输入。"
    fi

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

# 添加自动续签任务
green_text "正在添加自动续签任务..."
(crontab -l 2>/dev/null; echo "0 3 */30 * * /root/.acme.sh/acme.sh --renew -d $DOMAIN --quiet") | crontab -

green_text "自动续签任务已添加，每 30 天将尝试续签该域名证书。"
green_text "操作完成。"
