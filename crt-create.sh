#!/usr/bin/env bash
set -euo pipefail

show_help() {
  echo "Usage: $0 -m <machine_name>"
  echo ""
  echo "Options:"
  echo "  -m <machine_name>   Required. Machine name used as the certificate domain."
  echo "  -h                  Show this help message and exit."
}

# 初期化
MACHINE_NAME=""

# 引数解析
while getopts ":m:h" opt; do
  case ${opt} in
    m )
      MACHINE_NAME=$OPTARG
      ;;
    h )
      show_help
      exit 0
      ;;
    \? )
      echo "❌ Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
    : )
      echo "❌ Option -$OPTARG requires an argument." >&2
      show_help
      exit 1
      ;;
  esac
done

# 必須引数チェック
if [[ -z "${MACHINE_NAME}" ]]; then
  echo "❌ Machine name is required."
  show_help
  exit 1
fi

DOMAIN="${MACHINE_NAME}"
BASE_DIR="/opt/letsencrypt/live/${DOMAIN}"

echo "👉 Creating directory: ${BASE_DIR}"
sudo mkdir -p "${BASE_DIR}"

# 既存の証明書ファイルを削除
sudo rm -f "${BASE_DIR}/privkey.pem" "${BASE_DIR}/fullchain.pem" \
            "${BASE_DIR}/cert.pem" "${BASE_DIR}/key.pem"

echo "👉 Generating SAN-enabled self-signed cert for ${DOMAIN} ..."

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
OU = NO_DEPARTMENT

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${DOMAIN}
EOF
sudo openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "${BASE_DIR}/privkey.pem" \
  -out "${BASE_DIR}/fullchain.pem" \
  -days 365 \
  -config "${SAN_CONFIG}"

echo "👉 Changing ownership to ${USER}"
sudo chown "${USER}:${USER}" "${BASE_DIR}/privkey.pem" "${BASE_DIR}/fullchain.pem"
sudo chown "${USER}:${USER}" "${BASE_DIR}/fullchain.pem" "${BASE_DIR}/privkey.pem"

sudo ln -sf fullchain.pem "${BASE_DIR}/cert.pem"
sudo ln -sf privkey.pem "${BASE_DIR}/key.pem"

echo "👉 Setting permissions..."
sudo chmod 600 "${BASE_DIR}/privkey.pem" "${BASE_DIR}/key.pem"
sudo chmod 644 "${BASE_DIR}/fullchain.pem" "${BASE_DIR}/cert.pem"

echo "✅ Done. Certificates are at ${BASE_DIR}"
ls -l "${BASE_DIR}"
