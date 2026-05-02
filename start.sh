#!/bin/bash
# RunPod startup — launches ComfyUI on 0.0.0.0:8188 so RunPod's HTTP proxy
# can reach it. Logs go to stdout for the RunPod console.
set -e

echo "================================================"
echo "  WAN 2.2 Faceswap RunPod Template"
echo "  ComfyUI starting on port 8188..."
echo "================================================"

# Show GPU info for sanity
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || true
fi

cd /ComfyUI

# --listen 0.0.0.0 so RunPod proxy can reach it
# --port 8188 matches the EXPOSE in Dockerfile
# Pass through any extra args via $COMFY_ARGS env var if you want to customize
exec python main.py --listen 0.0.0.0 --port 8188 ${COMFY_ARGS:-}
