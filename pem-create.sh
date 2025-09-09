#!/usr/bin/env bash
set -euo pipefail

DOMAIN=$1
BASE_DIR="./letsencrypt/live/${DOMAIN}"

mkdir -p "${BASE_DIR}"

echo "👉 Generating self-signed cert for ${DOMAIN} ..."

# 秘密鍵と証明書の生成
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "${BASE_DIR}/privkey.pem" \
  -out "${BASE_DIR}/fullchain.pem" \
  -days 365 \
  -subj "/CN=${DOMAIN}"

# シンボリックリンク（Let's Encrypt 風の構造を再現）
ln -sf fullchain.pem "${BASE_DIR}/cert.pem"
ln -sf privkey.pem "${BASE_DIR}/key.pem"

# 権限を調整
echo "👉 Setting permissions..."
chmod 600 "${BASE_DIR}/privkey.pem"
chmod 644 "${BASE_DIR}/fullchain.pem" "${BASE_DIR}/cert.pem"
chmod 600 "${BASE_DIR}/key.pem"

echo "✅ Done. Certificates are at ${BASE_DIR}"
ls -l "${BASE_DIR}"