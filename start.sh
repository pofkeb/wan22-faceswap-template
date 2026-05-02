#!/bin/bash
set -e

echo "================================================"
echo "  WAN 2.2 Faceswap — aiempire/wan22videolora"
echo "  ComfyUI starting on port 8188..."
echo "================================================"

if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || true
fi

cd /ComfyUI
exec python main.py --listen 0.0.0.0 --port 8188 ${COMFY_ARGS:-}
