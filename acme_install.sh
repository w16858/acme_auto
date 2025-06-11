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

# 提示用户选择网络协议版本
green_text "请选择网络协议版本:"
echo "1) IPv4"
echo "2) IPv6"
green_text "输入选择 (1/2): "
read PROTOCOL_CHOICE

if [ "$PROTOCOL_CHOICE" -eq 1 ]; then
    IP_MODE="--listen-v4"
elif [ "$PROTOCOL_CHOICE" -eq 2 ]; then
    IP_MODE="--listen-v6"
else
    green_text "无效选择，退出。"
    exit 1
fi

# 提示用户输入域名
green_text "请输入要生成证书的域名: "
read DOMAIN

# 提示用户选择验证方式
green_text "请选择验证方式:"
echo "1) 临时 HTTP (standalone)"
echo "2) Web 目录验证 (webroot)"
echo "3) DNS 验证 (域名解析)"
echo "4) Cloudflare API 验证"
green_text "输入选择 (1/2/3/4): "
read METHOD_CHOICE

if [ "$METHOD_CHOICE" -eq 1 ]; then
    METHOD="--standalone $IP_MODE"
elif [ "$METHOD_CHOICE" -eq 2 ]; then
    green_text "请输入 Web 根目录路径: "
    read WEBROOT_PATH
    if [ ! -d "$WEBROOT_PATH" ]; then
        green_text "指定的 Web 根目录不存在，退出。"
        exit 1
    fi
    METHOD="-w $WEBROOT_PATH"
elif [ "$METHOD_CHOICE" -eq 3 ]; then
    # 自动获取 TXT 记录值
    green_text "正在获取需要配置的 DNS TXT 记录值..."
    /root/.acme.sh/acme.sh --issue -d "$DOMAIN" --dns $IP_MODE --debug > /tmp/dns_output.log 2>&1
    TXT_RECORD=$(grep -oP '(?<=_acme-challenge\.'"$DOMAIN"'\. ).*' /tmp/dns_output.log | head -1)

    if [ -z "$TXT_RECORD" ]; then
        green_text "获取 TXT 记录值失败，请检查日志文件: /tmp/dns_output.log"
        exit 1
    fi

    green_text "请登录 DNS 提供商管理面板，添加以下 TXT 记录："
    green_text "主机名: _acme-challenge.$DOMAIN"
    green_text "值: $TXT_RECORD"
    green_text "完成添加后，请输入 yes 继续: "
    read CONFIRMATION
    if [ "$CONFIRMATION" != "yes" ]; then
        green_text "操作取消，退出。"
        exit 1
    fi
    METHOD="--dns"
elif [ "$METHOD_CHOICE" -eq 4 ]; then
    # 检查是否已经设置了 Cloudflare API
    if grep -q "dns_cf" ~/.acme.sh/account.conf; then
        green_text "Cloudflare API 已设置，无需重新配置。"
    else
        green_text "Cloudflare API 环境变量未设置，请输入所需信息。"
        green_text "请输入 Cloudflare API Token: "
        read CF_Token
        green_text "请输入 Cloudflare Account ID: "
        read CF_Account_ID

        if [ -z "$CF_Token" ] || [ -z "$CF_Account_ID" ]; then
            green_text "输入为空，无法继续，请重新配置 Cloudflare API 环境变量后重试。"
            exit 1
        fi
        export CF_Token
        export CF_Account_ID
        green_text "Cloudflare API 配置成功。"
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

green_text "操作完成。"
