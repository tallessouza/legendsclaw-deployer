#!/usr/bin/env bash
set -euo pipefail

# Fix Docker MIN_API_VERSION
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF
systemctl daemon-reload
systemctl restart docker

# Limpa stacks
docker stack rm traefik 2>/dev/null || true
docker stack rm portainer 2>/dev/null || true
sleep 10
rm -f ~/traefik.yaml ~/portainer.yaml
docker volume prune -f
docker network rm claw 2>/dev/null || true

# Roda deployer
bash /root/deployer/deployer.sh
