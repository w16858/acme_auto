#!/bin/bash

# 检查并安装 acme.sh
if ! command -v acme.sh &>/dev/null; then
    echo "acme.sh 未安装，正在安装..."
    curl https://get.acme.sh | sh
    source ~/.bashrc
fi

# 提示用户选择验证方式
echo -e "\033[32m请选择验证方式:\033[0m"
echo "1) 临时 HTTP (standalone)"
echo "2) Cloudflare API 验证"
read -p "输入选择 (1/2): " METHOD_CHOICE

# 提示用户输入域名
read -p "请输入要生成证书的域名: " DOMAIN

# 检查是否已存在对应的域名目录
DOMAIN_DIR="/root/.acme.sh/${DOMAIN}_ecc"
if [ -d "$DOMAIN_DIR" ]; then
    echo -e "\033[31m检测到域名 ${DOMAIN} 的证书目录已存在: $DOMAIN_DIR\033[0m"
    read -p "是否删除该目录后重新申请？(y/n): " DELETE_CONFIRM
    if [ "$DELETE_CONFIRM" = "y" ] || [ "$DELETE_CONFIRM" = "Y" ]; then
        rm -rf "$DOMAIN_DIR"
        echo -e "\033[32m目录已删除。\033[0m"
    else
        echo -e "\033[31m操作取消。\033[0m"
        exit 1
    fi
fi

# 定义验证方式
if [ "$METHOD_CHOICE" -eq 1 ]; then
    # 自动检测域名类型（A 或 AAAA）
    IPV4_MODE="--listen-v4"
    IPV6_MODE="--listen-v6"

    echo -e "\033[32m正在检测域名解析记录...\033[0m"
    A_RECORD=$(dig +short A "$DOMAIN")
    AAAA_RECORD=$(dig +short AAAA "$DOMAIN")

    if [ -n "$A_RECORD" ]; then
        echo -e "\033[32m检测到 A 记录 (IPv4)，使用 IPv4 模式。\033[0m"
        METHOD="--standalone $IPV4_MODE"
    elif [ -n "$AAAA_RECORD" ]; then
        echo -e "\033[32m检测到 AAAA 记录 (IPv6)，使用 IPv6 模式。\033[0m"
        METHOD="--standalone $IPV6_MODE"
    else
        echo -e "\033[31m未检测到有效的 A 或 AAAA 记录，请检查域名解析。\033[0m"
        exit 1
    fi
elif [ "$METHOD_CHOICE" -eq 2 ]; then
    # Cloudflare API 验证
    echo -e "\033[32m使用 Cloudflare API 验证。\033[0m"
    read -p "请输入 Cloudflare API Token (留空取消): " CF_TOKEN
    read -p "请输入 Cloudflare Account ID (留空取消): " CF_ACCOUNT_ID

    if [ -z "$CF_TOKEN" ] || [ -z "$CF_ACCOUNT_ID" ]; then
        echo -e "\033[31mCloudflare API 配置未完成，操作取消。\033[0m"
        exit 1
    fi

    export CF_Token="$CF_TOKEN"
    export CF_Account_ID="$CF_ACCOUNT_ID"
    METHOD="--dns dns_cf"
else
    echo -e "\033[31m无效选择，退出。\033[0m"
    exit 1
fi

# 定义证书安装目录
CERT_DIR="/root/cert/$DOMAIN"
mkdir -p "$CERT_DIR"

# 开始申请证书
echo -e "\033[32m开始申请证书...\033[0m"
/root/.acme.sh/acme.sh --issue -d "$DOMAIN" $METHOD

if [ $? -ne 0 ]; then
    echo -e "\033[31m证书申请失败，请检查错误信息。\033[0m"
    exit 1
fi

# 安装证书到指定目录
echo -e "\033[32m安装证书到目录: $CERT_DIR\033[0m"
/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
--key-file "$CERT_DIR/privkey.pem" \
--fullchain-file "$CERT_DIR/fullchain.pem"

if [ $? -eq 0 ]; then
    echo -e "\033[32m证书申请和安装成功！\033[0m"
    echo "证书路径: $CERT_DIR/fullchain.pem"
    echo "私钥路径: $CERT_DIR/privkey.pem"
else
    echo -e "\033[31m证书安装失败，请检查错误信息。\033[0m"
    exit 1
fi

# 添加定时任务自动续签
CRON_JOB="@daily /root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /dev/null"
(crontab -l 2>/dev/null | grep -F "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
echo -e "\033[32m已添加自动续签任务，每天检查证书是否需要续签。\033[0m"

# 提示完成
echo -e "\033[32m操作完成。\033[0m"
