#!/usr/bin/env bash
set -euo pipefail
DOMAIN=$1
BASE_DIR="/opt/letsencrypt/live/${DOMAIN}"

mkdir -p "${BASE_DIR}"

# 既存の証明書ファイルを強制削除（再生成対応）
rm -f "${BASE_DIR}/privkey.pem" "${BASE_DIR}/fullchain.pem" \
      "${BASE_DIR}/cert.pem" "${BASE_DIR}/key.pem"

echo "👉 Generating SAN-enabled self-signed cert for ${DOMAIN} ..."

# 一時的な OpenSSL 設定ファイルを作成
SAN_CONFIG=$(mktemp)
trap 'rm -f "${SAN_CONFIG}"' EXIT

cat > "${SAN_CONFIG}" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
x509_extensions    = req_ext
prompt             = no

[ req_distinguished_name ]
CN = ${DOMAIN}
C = JP
ST = TOKYO
L = TOKYO
O = NO_COMPANY
OU = NO=DEPARTMENT

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${DOMAIN}
EOF

# 秘密鍵と証明書の生成（SAN付き）
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "${BASE_DIR}/privkey.pem" \
  -out "${BASE_DIR}/fullchain.pem" \
  -days 365 \
  -config "${SAN_CONFIG}"

# シンボリックリンク（Let's Encrypt 風の構造を再現）
ln -sf fullchain.pem "${BASE_DIR}/cert.pem"
ln -sf privkey.pem "${BASE_DIR}/key.pem"

# 権限を調整
echo "👉 Setting permissions..."
chmod 600 "${BASE_DIR}/privkey.pem" "${BASE_DIR}/key.pem"
chmod 644 "${BASE_DIR}/fullchain.pem" "${BASE_DIR}/cert.pem"

echo "✅ Done. Certificates are at ${BASE_DIR}"
ls -l "${BASE_DIR}"