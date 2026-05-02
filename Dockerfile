# =============================================================================
# WAN 2.2 T2V Faceswap (Icekiub workflow) — RunPod Template Image
# =============================================================================
# Builds a self-contained ComfyUI image with:
#   • ComfyUI + ComfyUI-Manager
#   • All custom nodes the workflow needs (VHS, KJNodes, Frame-Interpolation, RES4LYF)
#   • The Icy TikTok Downloader node (your custom node)
#   • The WAN 2.2 T2V Faceswap workflow JSON pre-loaded
#   • All required models baked in (~23GB)
# After deploy, the pod boots straight into a working ComfyUI on port 8188.
# =============================================================================

FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1

# -----------------------------------------------------------------------------
# System dependencies
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        wget \
        curl \
        ca-certificates \
        ffmpeg \
        libgl1 \
        libglib2.0-0 \
        aria2 \
    && rm -rf /var/lib/apt/lists/*

# Faster HF downloads
RUN pip install --no-cache-dir hf_transfer huggingface_hub

# -----------------------------------------------------------------------------
# ComfyUI core
# -----------------------------------------------------------------------------
WORKDIR /
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
WORKDIR /ComfyUI
RUN pip install --no-cache-dir -r requirements.txt

# ComfyUI-Manager (lets you install more nodes via UI later)
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git \
        /ComfyUI/custom_nodes/ComfyUI-Manager \
    && pip install --no-cache-dir -r /ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

# -----------------------------------------------------------------------------
# Custom nodes required by the workflow
#   VHS_*                        -> ComfyUI-VideoHelperSuite
#   ImageResizeKJv2 / Sage attn  -> ComfyUI-KJNodes
#   RIFE VFI                     -> ComfyUI-Frame-Interpolation
#   ClownsharKSampler_Beta       -> RES4LYF
# -----------------------------------------------------------------------------
RUN cd /ComfyUI/custom_nodes \
    && git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
    && git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes \
    && git clone --depth 1 https://github.com/Fannovel16/ComfyUI-Frame-Interpolation \
    && git clone --depth 1 https://github.com/ClownsharkBatwing/RES4LYF

# Install each node's requirements (best-effort; some optional deps may fail)
RUN for d in /ComfyUI/custom_nodes/*/; do \
        if [ -f "$d/requirements.txt" ]; then \
            echo "==> Installing requirements for $d" && \
            pip install --no-cache-dir -r "$d/requirements.txt" || \
                echo "WARN: some deps for $d failed (may still work)"; \
        fi; \
    done

# Sage Attention — required by PathchSageAttentionKJ node in the workflow.
# Best-effort install: if the wheel doesn't match the GPU/python combo, the
# workflow still runs (KJNodes falls back to standard attention).
RUN pip install --no-cache-dir sageattention || \
    echo "WARN: sageattention install failed — workflow still runs without it"

# -----------------------------------------------------------------------------
# Icy TikTok Downloader (your custom node)
# -----------------------------------------------------------------------------
COPY custom_node/ /ComfyUI/custom_nodes/ComfyUI-IcyTikTokDownloader/
RUN pip install --no-cache-dir \
        requests \
        opencv-python \
        numpy \
        yt-dlp

# -----------------------------------------------------------------------------
# Workflow — drops into the ComfyUI workflows browser automatically
# -----------------------------------------------------------------------------
RUN mkdir -p /ComfyUI/user/default/workflows
COPY workflow/ /ComfyUI/user/default/workflows/

# -----------------------------------------------------------------------------
# Models — split into separate RUN layers so failures are recoverable and
# Docker layer caching helps on rebuilds. ~23 GB total.
# -----------------------------------------------------------------------------
RUN mkdir -p \
    /ComfyUI/models/diffusion_models \
    /ComfyUI/models/text_encoders \
    /ComfyUI/models/vae \
    /ComfyUI/models/loras

# WAN 2.2 T2V low-noise FP8 (main diffusion model — ~16GB)
RUN wget --progress=dot:giga -O /ComfyUI/models/diffusion_models/WAN2.2t2vLOWNOISEFP8.safetensors \
    https://huggingface.co/icekiub/WAN-2.2-T2V-FP8-NON-SCALED/resolve/main/WAN2.2t2vLOWNOISEFP8.safetensors

# UMT5-XXL FP8 text encoder (~5.5 GB)
RUN wget --progress=dot:giga -O /ComfyUI/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors \
    https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors

# WAN 2.1 VAE (~250 MB)
RUN wget --progress=dot:giga -O /ComfyUI/models/vae/wan_2.1_vae.safetensors \
    https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors

# Lightning 4-step low-noise LoRA (~600 MB)
RUN wget --progress=dot:giga -O /ComfyUI/models/loras/low_noise_model.safetensors \
    https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-T2V-A14B-4steps-lora-250928/low_noise_model.safetensors

# -----------------------------------------------------------------------------
# Character LoRA — workflow expects: my_first_lora_v1_000000600_low_noise.safetensors
# Two ways to provide your own:
#   1) Upload via JupyterLab/web after pod start to /ComfyUI/models/loras/
#   2) Add a wget line here pointing to your hosted .safetensors and rebuild
# Uncomment & edit the line below to bake your own LoRA into the image:
# RUN wget -O /ComfyUI/models/loras/my_first_lora_v1_000000600_low_noise.safetensors \
#     https://your-host.example/your-character-lora.safetensors
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Startup
# -----------------------------------------------------------------------------
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188
WORKDIR /ComfyUI
CMD ["/start.sh"]
