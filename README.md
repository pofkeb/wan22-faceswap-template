# WAN 2.2 T2V Faceswap — RunPod Template

Self-contained RunPod template for Icekiub's WAN 2.2 T2V faceswap workflow. Pod boots straight into a working ComfyUI on port 8188 — all models, custom nodes, and the workflow itself baked into the image. No setup screen, no model-manager dance, no waiting on HuggingFace from inside the pod.

## What's inside

- **ComfyUI** + ComfyUI-Manager
- **Custom nodes:** VideoHelperSuite, KJNodes, Frame-Interpolation, RES4LYF, your Icy TikTok Downloader
- **Workflow:** `WANT2VLora_Faceswap_-_Icekiub_v1.json` pre-loaded
- **Models** (~23 GB, all baked in):
  - `WAN2.2t2vLOWNOISEFP8.safetensors` (diffusion)
  - `umt5_xxl_fp8_e4m3fn_scaled.safetensors` (text encoder)
  - `wan_2.1_vae.safetensors` (VAE)
  - `low_noise_model.safetensors` (Lightning 4-step LoRA)

## What you still need to provide

The workflow references a character LoRA named `my_first_lora_v1_000000600_low_noise.safetensors`. That's your trained LoRA. Three options:

1. **Upload after deploy** — open JupyterLab from the RunPod pod, drop the file into `/ComfyUI/models/loras/`. Easiest.
2. **Bake it into the image** — uncomment the commented `RUN wget` block at the bottom of the `Dockerfile` and point it at your hosted LoRA URL.
3. **Use a different filename** — edit the `LoraLoaderModelOnly` node in the workflow to match whatever your file is called.

## Repo layout

```
.
├── Dockerfile              # The image definition
├── start.sh                # Container entrypoint
├── .dockerignore
├── custom_node/            # Icy TikTok Downloader (your node)
│   ├── __init__.py
│   ├── icy_tiktok_downloader.py
│   ├── requirements.txt
│   └── js/                 # (empty — drop your icy_tiktok.js here for the snow animation)
├── workflow/
│   └── WANT2VLora_Faceswap_-_Icekiub_v1.json
└── .github/workflows/
    └── docker-build.yml    # Optional auto-build on push
```

---

## Build the image (two paths)

### Path A — GitHub Actions (recommended)

Building locally on residential internet means uploading ~30 GB to Docker Hub, which can take many hours. GitHub Actions runners have datacenter bandwidth and do it in ~20 minutes. Setup:

1. Push this folder to a new GitHub repo.
2. On Docker Hub: Account Settings → Security → New Access Token. Copy it.
3. On the GitHub repo: Settings → Secrets and variables → Actions → New repository secret. Add two:
   - `DOCKERHUB_USERNAME` — your Docker Hub username
   - `DOCKERHUB_TOKEN` — the token from step 2
4. Edit `.github/workflows/docker-build.yml` — change `IMAGE_NAME: wan22-faceswap-runpod` to whatever you want the repo on Docker Hub to be called.
5. Push to `main` (or click Actions → "Build & Push Docker image" → Run workflow).
6. When it finishes (~20-30 min the first time, ~5 min on subsequent builds thanks to layer caching), your image is at `docker.io/YOUR_USERNAME/wan22-faceswap-runpod:latest`.

### Path B — Build locally and push

```bash
# Replace YOUR_DOCKERHUB_USERNAME with your actual username
docker build -t YOUR_DOCKERHUB_USERNAME/wan22-faceswap-runpod:latest .
docker login
docker push YOUR_DOCKERHUB_USERNAME/wan22-faceswap-runpod:latest
```

Expect the build to use ~50 GB of disk (intermediate layers + final image), and the push to take 30 min – several hours depending on your upload speed.

---

## Create the RunPod template

1. Sign in to RunPod → **Templates** (left nav) → **New Template**.
2. Fill in:
   - **Template Name:** `WAN 2.2 Faceswap` (or whatever)
   - **Container Image:** `YOUR_DOCKERHUB_USERNAME/wan22-faceswap-runpod:latest`
   - **Container Disk:** `60 GB` (image is ~30 GB, plus headroom for downloaded TikToks and outputs)
   - **Volume Disk:** `0 GB` (everything is in the container — only set this if you want persistent outputs across pod resets)
   - **Volume Mount Path:** leave blank
   - **Expose HTTP Ports:** `8188`
   - **Expose TCP Ports:** leave blank
   - **Container Start Command:** leave blank (uses `CMD` from the Dockerfile)
   - **Environment Variables:** none required. Optionally set `COMFY_ARGS` to extra ComfyUI flags (e.g. `--lowvram`, `--use-sage-attention`).
3. Save.

## Deploy a pod from the template

1. **Pods** (left nav) → **Deploy**.
2. Pick a GPU. Recommendations for this workflow:
   - **24 GB VRAM minimum** (RTX 4090, RTX A5000, L4) — works but tight
   - **48 GB VRAM** (RTX A6000, L40, RTX 6000 Ada) — comfortable
   - For Blackwell GPUs (5090, B200) you may need to update the base image to a CUDA 12.8 build — see "Notes" below.
3. **Pod Template:** select the one you just created.
4. Container Disk should already be 60 GB from the template.
5. **Deploy On-Demand**.
6. Once status is **Running**, click **Connect → HTTP Service [Port 8188]**. ComfyUI loads.
7. **Workflow** (top right) → **Browse Workflows** → pick **WANT2VLora_Faceswap_-_Icekiub_v1**. The workflow is already there.
8. Drop in your character LoRA (see "What you still need to provide" above), paste a TikTok URL into the Icy TikTok node, **Queue Prompt**.

When done: **Stop** the pod (you stop paying the GPU rate but keep the disk for ~$0.10/GB/month) or **Terminate** it (everything is wiped — fine since the image rebuilds it from scratch).

---

## Notes

**CUDA / GPU compatibility.** Base image is `pytorch/pytorch:2.4.0-cuda12.4-cudnn9-devel`, which works on Ampere (3090, A100), Ada (4090, L40, A6000 Ada), and Hopper (H100). For Blackwell (5090, B200), bump the base in the Dockerfile to a CUDA 12.8 PyTorch image.

**Sage Attention.** The workflow uses the `PathchSageAttentionKJ` node. The Dockerfile installs `sageattention` best-effort — if the wheel doesn't match the GPU, KJNodes silently falls back to standard attention. You'll just lose some speed, the workflow still runs.

**RIFE checkpoint.** `rife47.pth` is auto-downloaded by ComfyUI-Frame-Interpolation on first use (~80 MB). If you want it baked in too, add a `RUN wget` line for `https://github.com/Fannovel16/ComfyUI-Frame-Interpolation/releases/download/models/rife47.pth` into `/ComfyUI/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/`.

**Snow animation JS missing.** The cosmetic blue-gradient snow theme JS file wasn't in the upload (turned out to be a misnamed `.pyc`). The node works fine without it. If you have the real `icy_tiktok.js`, drop it in `custom_node/js/` and rebuild — the `__init__.py` already wires `WEB_DIRECTORY = "./js"`.

**Updating models or nodes.** Edit the Dockerfile, push, GitHub Actions rebuilds. Layer caching means only the changed layer (and ones after it) rebuild, so put your most-likely-to-change RUN commands near the bottom.

**One-click deploy link.** Once your template is created in RunPod, you can grab a `runpod.io/console/deploy?template=XXXXXX&ref=YYY` URL from the template page and share it. Anyone clicking it gets your template pre-selected.
