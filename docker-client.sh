#!/bin/bash# ヘルプ表示関数
set -euo pipefail
show_help() {
  echo "Usage: $0 -r <registry-host> -u <registry-user> -c <client-host>"
  echo "  -r : レジストリホスト名（必須）"
  echo "  -u : レジストリホストのユーザー名（必須）"
  echo "  -c : クライアントホスト名（必須）"
  exit 1
}

# 引数解析
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -r)
      REGISTRY_HOST="$2"
      shift; shift
      ;;
    -u)
      REGISTRY_HOST_USER="$2"
      shift; shift
      ;;
    -c)
      CLIENT_HOST="$2"
      shift; shift
      ;;
    *)
      show_help
      ;;
  esac
done

# 必須引数チェック
if [ -z "$REGISTRY_HOST" ] || [ -z "$REGISTRY_HOST_USER" ] || [ -z "$CLIENT_HOST" ]; then
  show_help
fi

# IPアドレス取得
REGISTRY_HOST_IP=$(getent hosts "$REGISTRY_HOST" | awk '{ print $1 }')
if [ -z "$REGISTRY_HOST_IP" ]; then
  echo "❌ IPアドレスの取得に失敗しました: ${REGISTRY_HOST}"
  exit 1
fi
echo "🔍 レジストリホストIP: ${REGISTRY_HOST_IP}"

# 証明書ファイルの存在確認
REMOTE_CERT_PATH="/opt/letsencrypt/live/${REGISTRY_HOST}/fullchain.pem"
ssh "${REGISTRY_HOST_USER}@${REGISTRY_HOST}" "test -f ${REMOTE_CERT_PATH}"
if [ $? -ne 0 ]; then
  echo "❌ 証明書ファイルが存在しません: ${REMOTE_CERT_PATH}"
  exit 1
fi

# 1. Dockerデーモン設定（insecure-registries）
echo "⚙️ /etc/docker/daemon.json を作成・上書きします..."
sudo bash -c "cat > /etc/docker/daemon.json <<EOF
{
  \"insecure-registries\" : [\"${REGISTRY_HOST_IP}:5000\", \"${REGISTRY_HOST}:5000\"]
}
EOF"

# 2. 証明書ディレクトリ作成とコピー
CERT_DIR="/etc/docker/certs.d/${REGISTRY_HOST}:5000"
echo "📁 証明書ディレクトリ: ${CERT_DIR} を作成します..."
sudo mkdir -p "${CERT_DIR}"
echo "📦 証明書を ${REGISTRY_HOST} からコピーします..."
sudo scp "${REGISTRY_HOST_USER}@${REGISTRY_HOST}:${REMOTE_CERT_PATH}" "${CERT_DIR}/ca.crt"

# 3. Dockerデーモン再起動
echo "🔄 Dockerデーモンを再起動します..."
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "✅ 設定完了: ${CLIENT_HOST} から ${REGISTRY_HOST}:5000 への安全なアクセスが可能になりました。"
