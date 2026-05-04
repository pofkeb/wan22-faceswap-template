#!/bin/bash
set -e

echo "================================================"
echo "  WAN 2.2 Faceswap — aiempire/wan22videolora"
echo "  ComfyUI on :8188   |   JupyterLab on :8888"
echo "================================================"

if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || true
fi

# Start JupyterLab in the background
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.disable_check_xsrf=True \
    --notebook-dir=/ComfyUI \
    &

# Start ComfyUI in the foreground (keeps container alive)
cd /ComfyUI
exec python main.py --listen 0.0.0.0 --port 8188 ${COMFY_ARGS:-}
