# =============================================================================
# WAN 2.2 T2V Faceswap (Icekiub workflow) — RunPod Template Image
# Image: aiempire/wan22videolora
# =============================================================================

FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        git wget curl ca-certificates ffmpeg libgl1 libglib2.0-0 aria2 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir hf_transfer huggingface_hub

# ComfyUI
WORKDIR /
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
WORKDIR /ComfyUI
RUN pip install --no-cache-dir -r requirements.txt

# ComfyUI-Manager
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git \
        /ComfyUI/custom_nodes/ComfyUI-Manager \
    && pip install --no-cache-dir -r /ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

# Custom nodes used by the workflow
RUN cd /ComfyUI/custom_nodes \
    && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
    && git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes \
    && git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation \
    && git clone --depth 1 https://github.com/ClownsharkBatwing/RES4LYF

RUN for d in /ComfyUI/custom_nodes/*/; do \
        if [ -f "$d/requirements.txt" ]; then \
            pip install --no-cache-dir -r "$d/requirements.txt" || \
                echo "WARN: some deps for $d failed (may still work)"; \
        fi; \
    done

# Sage Attention (best-effort)
RUN pip install --no-cache-dir sageattention || \
    echo "WARN: sageattention install failed — workflow runs without it"

# Icy TikTok Downloader (your custom node)
COPY custom_node/ /ComfyUI/custom_nodes/ComfyUI-IcyTikTokDownloader/
RUN pip install --no-cache-dir requests opencv-python numpy yt-dlp

# Workflow
RUN mkdir -p /ComfyUI/user/default/workflows
COPY workflow/ /ComfyUI/user/default/workflows/

# Models (~23 GB total)
RUN mkdir -p \
    /ComfyUI/models/diffusion_models \
    /ComfyUI/models/text_encoders \
    /ComfyUI/models/vae \
    /ComfyUI/models/loras

# WAN 2.2 T2V FP8 (~16 GB)
RUN wget --progress=dot:giga -O /ComfyUI/models/diffusion_models/WAN2.2t2vLOWNOISEFP8.safetensors \
    https://huggingface.co/icekiub/WAN-2.2-T2V-FP8-NON-SCALED/resolve/main/WAN2.2t2vLOWNOISEFP8.safetensors

# Text encoder (~5.5 GB)
RUN wget --progress=dot:giga -O /ComfyUI/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors \
    https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors

# VAE (~250 MB)
RUN wget --progress=dot:giga -O /ComfyUI/models/vae/wan_2.1_vae.safetensors \
    https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors

# Lightning 4-step LoRA (~600 MB)
RUN wget --progress=dot:giga -O /ComfyUI/models/loras/low_noise_model.safetensors \
    https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-250928/low_noise_model.safetensors

# Startup
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188
WORKDIR /ComfyUI
CMD ["/start.sh"]
