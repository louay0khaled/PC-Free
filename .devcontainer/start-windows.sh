#!/usr/bin/env bash
set -euo pipefail

# PC-Free: start a persistent Windows 10 VM in dockur/windows.
# This is designed for GitHub Codespaces and requires no local PC.

DATA_DIR="${CODESPACE_VSCODE_FOLDER:-$PWD}/.windows-data"
CONTAINER="pc-free-windows"
IMAGE="dockurr/windows"
mkdir -p "$DATA_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not available yet. Restart/rebuild the Codespace and try again."
  exit 1
fi

# Wait briefly for the Docker-in-Docker daemon.
for i in {1..30}; do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

docker info >/dev/null 2>&1 || { echo "Docker daemon did not become ready."; exit 1; }

# Reuse an existing VM so Windows data survives Codespace restarts.
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    docker start "$CONTAINER" >/dev/null
  fi
  echo "Windows is already configured. Open forwarded port 8006 in the Ports tab."
  exit 0
fi

echo "Pulling $IMAGE (first run can take several minutes)..."
docker pull "$IMAGE"

RUN_ARGS=(
  -d
  --name "$CONTAINER"
  --cap-add NET_ADMIN
  -e VERSION=10
  -e RAM_SIZE=6G
  -e CPU_CORES=2
  -e DISK_SIZE=16G
  -p 8006:8006
  -v "$DATA_DIR:/storage"
  --stop-timeout 120
)

# KVM gives much better performance when the Codespace host exposes it.
if [ -e /dev/kvm ]; then
  RUN_ARGS+=(--device /dev/kvm -e KVM=Y)
  echo "KVM detected: hardware acceleration enabled."
else
  RUN_ARGS+=(-e KVM=N)
  echo "KVM is not exposed by this Codespace; using software emulation."
fi

if [ -e /dev/net/tun ]; then
  RUN_ARGS+=(--device /dev/net/tun)
fi

docker run "${RUN_ARGS[@]}" "$IMAGE"

echo
 echo "Windows 10 is starting. Open the forwarded port 8006 from the Codespaces Ports tab."
 echo "First boot may take several minutes while the Windows image is prepared."
