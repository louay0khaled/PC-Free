#!/usr/bin/env bash
set -euo pipefail

# PC-Free: start a persistent Windows 7 VM in dockur/windows.
# Designed for GitHub Codespaces; no local PC required.

DATA_DIR="${CODESPACE_VSCODE_FOLDER:-$PWD}/.windows-data"
CONTAINER="pc-free-windows"
IMAGE="dockurr/windows"
mkdir -p "$DATA_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not available yet. Restart/rebuild the Codespace and try again."
  exit 1
fi

for i in {1..30}; do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

docker info >/dev/null 2>&1 || { echo "Docker daemon did not become ready."; exit 1; }

# If an older VM exists, keep its data only when it is already the requested OS.
# The Windows 10 VM must be removed manually once so the new Windows 7 image can be created.
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Existing Windows container detected. To switch from the previous Windows version, run:"
  echo "docker rm -f $CONTAINER"
  exit 1
fi

echo "Pulling $IMAGE (Windows 7 image is about 3 GB)..."
docker pull "$IMAGE"

RUN_ARGS=(
  -d
  --name "$CONTAINER"
  --cap-add NET_ADMIN
  -e VERSION=win7
  -e RAM_SIZE=4G
  -e CPU_CORES=2
  -e DISK_SIZE=16G
  -p 8006:8006
  -v "$DATA_DIR:/storage"
  --stop-timeout 120
)

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
echo "Windows 7 is starting. Open forwarded port 8006 from the Codespaces Ports tab."
echo "First boot may take several minutes while the Windows image is prepared."
