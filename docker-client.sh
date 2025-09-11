#!/bin/bash

# ヘルプ表示関数
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
      if [[ -z "$2" ]]; then echo "❌ -r オプションに値が必要です"; show_help; fi
      REGISTRY_HOST="$2"
      shift; shift
      ;;
    -u)
      if [[ -z "$2" ]]; then echo "❌ -u オプションに値が必要です"; show_help; fi
      REGISTRY_HOST_USER="$2"
      shift; shift
      ;;
    -c)
      if [[ -z "$2" ]]; then echo "❌ -c オプションに値が必要です"; show_help; fi
      CLIENT_HOST="$2"
      shift; shift
      ;;
    *)
      echo "❌ 不明なオプション: $1"
      show_help
      ;;
  esac
done

# 必須引数チェック
if [[ -z "$REGISTRY_HOST" || -z "$REGISTRY_HOST_USER" || -z "$CLIENT_HOST" ]]; then
  echo "❌ 必須引数が不足しています"
  show_help
fi

# sudo コマンド確認
if ! command -v sudo &> /dev/null; then
  echo "❌ sudo コマンドが見つかりません。インストールまたは権限確認してください。"
  exit 1
fi

# IPアドレス取得
REGISTRY_HOST_IP=$(getent hosts "$REGISTRY_HOST" | awk '{ print $1 }')
if [[ -z "$REGISTRY_HOST_IP" ]]; then
  echo "❌ IPアドレスの取得に失敗しました: ${REGISTRY_HOST}"
  exit 1
fi
echo "🔍 レジストリホストIP: ${REGISTRY_HOST_IP}"

# 証明書ファイルの存在確認
REMOTE_CERT_PATH="/opt/letsencrypt/live/${REGISTRY_HOST}/fullchain.pem"
ssh "${REGISTRY_HOST_USER}@${REGISTRY_HOST}" "test -f ${REMOTE_CERT_PATH}"
if [[ $? -ne 0 ]]; then
  echo "❌ 証明書ファイルが存在しません: ${REMOTE_CERT_PATH}"
  exit 1
fi

# Dockerデーモン設定
echo "⚙️ /etc/docker/daemon.json を作成・上書きします..."
sudo bash -c "cat > /etc/docker/daemon.json <<EOF
{
  \"insecure-registries\" : [\"${REGISTRY_HOST_IP}:5000\", \"${REGISTRY_HOST}:5000\"]
}
EOF"

# 証明書ディレクトリ作成とコピー
CERT_DIR="/etc/docker/certs.d/${REGISTRY_HOST}:5000"
echo "📁 証明書ディレクトリ: ${CERT_DIR} を作成します..."
sudo mkdir -p "${CERT_DIR}"

echo "📦 証明書を ${REGISTRY_HOST} からコピーします..."
sudo scp "${REGISTRY_HOST_USER}@${REGISTRY_HOST}:${REMOTE_CERT_PATH}" "${CERT_DIR}/ca.crt"
if [[ $? -ne 0 ]]; then
  echo "❌ 証明書のコピーに失敗しました。SSH接続やパスを確認してください。"
  exit 1
fi

# Dockerデーモン再起動
echo "🔄 Dockerデーモンを再起動します..."
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "✅ 設定完了: ${CLIENT_HOST} から ${REGISTRY_HOST}:5000 への安全なアクセスが可能になりました。"