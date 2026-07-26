#!/usr/bin/env bash
# Runs the E2EE end-to-end integration test on a connected Android device
# against a locally running backend (see integration_test/e2ee_flow_test.dart).
#
# Prerequisites: a migrated backend listening on :8080
#   cd ../homl-web && make db-up && make migrateup && make local   # or make dev
#
# Usage: ./run-e2e-test.sh [device-id]
#   device-id defaults to the first attached device; emulators reach the host
#   via 10.0.2.2, physical phones via the LAN IP (auto-detected).
set -euo pipefail

export PATH="$HOME/.local/flutter/bin:$PATH"
cd "$(dirname "$0")"

DEVICE="${1:-$(adb devices | awk 'NR==2 && $2=="device" {print $1}')}"
if [ -z "$DEVICE" ]; then
  echo "No device attached (adb devices)" >&2
  exit 1
fi

if [[ "$DEVICE" == emulator-* ]]; then
  HOST=10.0.2.2
else
  # Physical phone: it must reach this machine over the LAN.
  HOST=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
fi

echo "Device: $DEVICE — backend: http://$HOST:8080/api"
flutter test integration_test/e2ee_flow_test.dart \
  -d "$DEVICE" \
  --dart-define=API_BASE_URL="http://$HOST:8080/api"
