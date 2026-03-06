#!/bin/bash
set -e

# Script deploy SmartRent lên Droplet
# Chạy lần đầu (root): bash deploy.sh setup
# Cập nhật image mới: bash deploy.sh update

DEPLOY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE="docker compose \
  --env-file $DEPLOY_DIR/docker/.env \
  --env-file $DEPLOY_DIR/docker/tags.env \
  -f $DEPLOY_DIR/docker/docker-compose.yml"

setup() {
  echo "==> Cài đặt Docker..."
  apt-get update -q
  apt-get install -y -q ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin

  echo "==> Docker cài xong: $(docker --version)"

  echo "==> Tạo user deploy..."
  if ! id "deploy" &>/dev/null; then
    adduser --disabled-password --gecos "" deploy
    usermod -aG docker deploy
    echo "User 'deploy' đã được tạo và thêm vào group docker."
  else
    echo "User 'deploy' đã tồn tại."
  fi

  mkdir -p /home/deploy/.ssh
  if [ -f /root/.ssh/authorized_keys ]; then
    cp /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
    chown -R deploy:deploy /home/deploy/.ssh
    chmod 700 /home/deploy/.ssh
    chmod 600 /home/deploy/.ssh/authorized_keys
    echo "Đã copy SSH key từ root sang deploy."
  else
    echo "WARNING: Không tìm thấy /root/.ssh/authorized_keys. Hãy thêm SSH key thủ công."
  fi

  if [ ! -f "$DEPLOY_DIR/docker/.env" ]; then
    echo "ERROR: File docker/.env chưa tồn tại. Hãy copy .env.example thành .env và điền giá trị trước."
    exit 1
  fi

  echo "==> Khởi động toàn bộ services..."
  $COMPOSE up -d

  echo "==> Xong! Kiểm tra status:"
  $COMPOSE ps
}

update() {
  local service="${2:-backend}"

  echo "==> Sync code từ git..."
  git -C "$DEPLOY_DIR" fetch origin main
  git -C "$DEPLOY_DIR" reset --hard origin/main

  echo "==> Pull image mới: $service..."
  $COMPOSE pull "$service"

  echo "==> Restart service: $service..."
  $COMPOSE up -d --no-deps "$service"

  echo "==> Xong! Status:"
  $COMPOSE ps
}

logs() {
  $COMPOSE logs -f --tail=100 "${2:-backend}"
}

stop() {
  $COMPOSE down
}

rollback() {
  local steps="${2:-1}"
  echo "==> Rollback $steps commit..."
  git -C "$DEPLOY_DIR" fetch origin main
  git -C "$DEPLOY_DIR" reset --hard "origin/main~$steps"

  echo "==> Pull image theo tags.env cũ..."
  $COMPOSE pull backend
  $COMPOSE up -d --no-deps backend

  echo "==> Rollback xong! tags.env hiện tại:"
  cat "$DEPLOY_DIR/docker/tags.env"
}

case "$1" in
  setup)    setup "$@" ;;
  update)   update "$@" ;;
  logs)     logs "$@" ;;
  stop)     stop ;;
  rollback) rollback "$@" ;;
  *)
    echo "Usage: $0 {setup|update [service]|logs [service]|stop|rollback [steps]}"
    echo "  setup          - Cài Docker, tạo user deploy, khởi động lần đầu (chạy bằng root)"
    echo "  update         - Sync git, pull image mới và restart (mặc định: backend)"
    echo "  update scraper - Restart service scraper"
    echo "  logs           - Xem logs (mặc định: backend)"
    echo "  stop           - Dừng tất cả services"
    echo "  rollback [n]   - Rollback về n commit trước (mặc định: 1)"
    exit 1
    ;;
esac
