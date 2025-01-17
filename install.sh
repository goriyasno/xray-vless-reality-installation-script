#!/bin/bash

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)"

server_ip=$(curl -s https://api.ipify.org)

uuid=$(xray uuid)
shortId=$(openssl rand -hex 8)

#uuid="18c9f4c4-8128-41dd-adac-b5f8b32d1d9b"
#shortId="26c748c00272f7ca"

# Generate key pair
keys=$(xray x25519)
private_key=$(echo "$keys" | awk '/Private key:/ {print $3}')
public_key=$(echo "$keys" | awk '/Public key:/ {print $3}')

#private_key="8CMf9TiK4R6q0lPTSe8mYLioBb0k8bKLGk9cDXmakRA"
#public_key="LfvHLMdDNyqjS7fmFd0z8QS9VifhpXiXaYQr5fGs-E8"

# Generate server configuration
configure_server() {
    echo "Generating server configuration..."
    mv /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.b
    cat <<EOF >/usr/local/etc/xray/config.json
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "xtls-rprx-vision",
                        "level": 0
                    }
                ],
                "decryption": "none",
                "fallbacks": []
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.google-analytics.com:443",
                    "xver": 0,
                    "serverNames": ["www.google-analytics.com"],
                    "privateKey": "$private_key",
                    "shortIds": ["$shortId"]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls", "quic"]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF
}

# Generate client configuration
configure_client() {
    echo "Generating client configuration..."

    cat <<EOF >~/client-config.json
{
    "dns": {
        "disableFallback": true,
        "servers": [
            {
                "address": "https://8.8.8.8/dns-query",
                "domains": [],
                "queryStrategy": ""
            },
            { "address": "localhost", "domains": [], "queryStrategy": "" }
        ],
        "tag": "dns"
    },
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": 2080,
            "protocol": "socks",
            "settings": { "udp": true },
            "sniffing": {
                "destOverride": ["http", "tls", "quic"],
                "enabled": true,
                "metadataOnly": false,
                "routeOnly": true
            },
            "tag": "socks-in"
        }
    ],
    "log": { "loglevel": "warning" },
    "outbounds": [
        {
            "domainStrategy": "AsIs",
            "protocol": "vless",
            "settings": {
                "vnext": [
                    {
                        "address": "${server_ip}",
                        "port": 443,
                        "users": [
                            {
                                "encryption": "none",
                                "flow": "xtls-rprx-vision",
                                "id": "${uuid}"
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "realitySettings": {
                    "fingerprint": "chrome",
                    "publicKey": "$public_key",
                    "serverName": "www.google-analytics.com",
                    "shortId": "$shortId",
                    "spiderX": "/"
                },
                "security": "reality"
            },
            "tag": "proxy"
        },
        { "domainStrategy": "", "protocol": "freedom", "tag": "direct" },
        { "domainStrategy": "", "protocol": "freedom", "tag": "bypass" },
        { "protocol": "blackhole", "tag": "block" },
        {
            "protocol": "dns",
            "proxySettings": { "tag": "proxy", "transportLayer": true },
            "settings": {
                "address": "8.8.8.8",
                "network": "tcp",
                "port": 53,
                "userLevel": 1
            },
            "tag": "dns-out"
        }
    ],
    "policy": {
        "levels": { "1": { "connIdle": 30 } },
        "system": { "statsOutboundDownlink": true, "statsOutboundUplink": true }
    },
    "routing": {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "inboundTag": ["socks-in", "http-in"],
                "outboundTag": "dns-out",
                "port": "53",
                "type": "field"
            },
            { "outboundTag": "proxy", "port": "0-65535", "type": "field" }
        ]
    },
    "stats": {}
}

EOF

}

# Main script
main() {
    configure_server
    configure_client
    vless_reality_url="vless://$uuid@$server_ip:443?flow=xtls-rprx-vision&encryption=none&type=tcp&security=reality&sni=www.google-analytics.com&fp=chrome&pbk=$public_key&sid=$shortId&spx=/&#XRAY_SERVER"
    echo "VLESS=$vless_reality_url"
}

main
