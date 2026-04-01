#!/bin/bash
# ============================================================
#  PROJECTO KIKA — Wan 2.2 I2V 14B FP8
#  Vast.ai A100 40GB | ComfyUI fresh clone
#  github.com/flavi0costa/kika-vastai
# ============================================================

LOG="/workspace/provision.log"
exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo "  PROJECTO KIKA — Wan 2.2 I2V 14B FP8"
echo "  $(date)"
echo "============================================================"

set -e

COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
HF="https://huggingface.co"

# ------------------------------------------------------------
# PASSO 1 — ComfyUI clone fresco (NUNCA git pull)
# ------------------------------------------------------------
echo ""
echo "[1/6] Clone fresco ComfyUI..."

cd /workspace
rm -rf "$COMFY"
git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY"
cd "$COMFY"
pip install -q -r requirements.txt

echo "  ✅ ComfyUI $(git rev-parse --short HEAD)"

# ------------------------------------------------------------
# PASSO 2 — VideoHelperSuite (para guardar MP4)
# ------------------------------------------------------------
echo ""
echo "[2/6] Custom nodes..."

cd "$COMFY/custom_nodes"
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
pip install -q -r ComfyUI-VideoHelperSuite/requirements.txt

echo "  ✅ VideoHelperSuite pronto"

# ------------------------------------------------------------
# PASSO 3 — Estrutura de pastas
# ------------------------------------------------------------
echo ""
echo "[3/6] Criar pastas..."

mkdir -p "$MODELS/diffusion_models"
mkdir -p "$MODELS/text_encoders"
mkdir -p "$MODELS/vae"
mkdir -p "$MODELS/clip_vision"
mkdir -p "$COMFY/input/kika_ep1"
mkdir -p "$COMFY/output/kika_ep1"

echo "  ✅ Pastas criadas"

# ------------------------------------------------------------
# PASSO 4 — Download modelos Wan 2.2 I2V 14B FP8
# Fonte oficial: Comfy-Org/Wan_2.2_ComfyUI_Repackaged
# ------------------------------------------------------------
echo ""
echo "[4/6] Download modelos (~38GB)..."

download() {
    local URL="$1"
    local DEST="$2"
    local NAME=$(basename "$DEST")

    if [ -f "$DEST" ] && [ $(stat -c%s "$DEST") -gt 1000000 ]; then
        echo "  ⏭️  $NAME já existe"
        return 0
    fi

    echo "  ⬇️  $NAME..."
    wget -q --show-progress -c "$URL" -O "$DEST"

    if [ -f "$DEST" ] && [ $(stat -c%s "$DEST") -gt 1000000 ]; then
        echo "  ✅ $NAME ($(du -sh $DEST | cut -f1))"
    else
        echo "  ❌ ERRO: $NAME"
        exit 1
    fi
}

BASE="$HF/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files"

download "$BASE/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
         "$MODELS/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"

download "$BASE/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
         "$MODELS/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"

download "$BASE/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
         "$MODELS/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

download "$BASE/vae/wan_2.1_vae.safetensors" \
         "$MODELS/vae/wan_2.1_vae.safetensors"

download "$BASE/clip_vision/clip_vision_h.safetensors" \
         "$MODELS/clip_vision/clip_vision_h.safetensors"

echo ""
echo "  📦 Total modelos:"
du -sh "$MODELS"/*/  2>/dev/null

# ------------------------------------------------------------
# PASSO 5 — Workflow I2V 14B com VHS_VideoCombine (MP4)
# Baseado no workflow oficial comfyanonymous/ComfyUI_examples
# Modificado: SaveWEBM → VHS_VideoCombine (MP4 h264)
# ------------------------------------------------------------
echo ""
echo "[5/6] Criar workflow..."

cat > "$COMFY/input/kika_ep1/wan22_i2v_14B_kika.json" << 'WORKFLOW_EOF'
{
  "last_node_id": 65,
  "last_link_id": 130,
  "nodes": [
    {
      "id": 38,
      "type": "CLIPLoader",
      "pos": [30, 190],
      "size": [360, 106],
      "order": 0,
      "mode": 0,
      "inputs": [],
      "outputs": [{"name": "CLIP", "type": "CLIP", "slot_index": 0, "links": [74, 75]}],
      "widgets_values": ["umt5_xxl_fp8_e4m3fn_scaled.safetensors", "wan", "default"]
    },
    {
      "id": 37,
      "type": "UNETLoader",
      "pos": [30, -70],
      "size": [430, 82],
      "order": 1,
      "mode": 0,
      "inputs": [],
      "outputs": [{"name": "MODEL", "type": "MODEL", "slot_index": 0, "links": [110]}],
      "widgets_values": ["wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors", "default"]
    },
    {
      "id": 56,
      "type": "UNETLoader",
      "pos": [30, 60],
      "size": [430, 82],
      "order": 2,
      "mode": 0,
      "inputs": [],
      "outputs": [{"name": "MODEL", "type": "MODEL", "slot_index": 0, "links": [112]}],
      "widgets_values": ["wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors", "default"]
    },
    {
      "id": 39,
      "type": "VAELoader",
      "pos": [30, 340],
      "size": [360, 58],
      "order": 3,
      "mode": 0,
      "inputs": [],
      "outputs": [{"name": "VAE", "type": "VAE", "slot_index": 0, "links": [76, 99]}],
      "widgets_values": ["wan_2.1_vae.safetensors"]
    },
    {
      "id": 52,
      "type": "LoadImage",
      "pos": [-50, 550],
      "size": [450, 540],
      "order": 4,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {"name": "IMAGE", "type": "IMAGE", "slot_index": 0, "links": [126]},
        {"name": "MASK", "type": "MASK", "slot_index": 1, "links": null}
      ],
      "widgets_values": ["kika.png", "image"]
    },
    {
      "id": 6,
      "type": "CLIPTextEncode",
      "title": "Positive Prompt",
      "pos": [415, 186],
      "size": [422, 164],
      "order": 5,
      "mode": 0,
      "inputs": [{"name": "clip", "type": "CLIP", "link": 74}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "slot_index": 0, "links": [97]}],
      "widgets_values": ["A cheerful cartoon girl chef with blonde curly hair and green eyes wearing a white chef coat, runs joyfully into a colorful cartoon kitchen, smooth natural animation, warm lighting, expressive face, fluid motion"]
    },
    {
      "id": 7,
      "type": "CLIPTextEncode",
      "title": "Negative Prompt",
      "pos": [413, 389],
      "size": [425, 180],
      "order": 6,
      "mode": 0,
      "inputs": [{"name": "clip", "type": "CLIP", "link": 75}],
      "outputs": [{"name": "CONDITIONING", "type": "CONDITIONING", "slot_index": 0, "links": [98]}],
      "widgets_values": ["blurry, low quality, distorted, ugly, deformed, static, frozen, noise, artifacts, watermark, text, extra limbs"]
    },
    {
      "id": 54,
      "type": "ModelSamplingSD3",
      "pos": [486, -69],
      "size": [315, 58],
      "order": 7,
      "mode": 0,
      "inputs": [{"name": "model", "type": "MODEL", "link": 110}],
      "outputs": [{"name": "MODEL", "type": "MODEL", "slot_index": 0, "links": [125]}],
      "widgets_values": [8.0]
    },
    {
      "id": 55,
      "type": "ModelSamplingSD3",
      "pos": [484, 54],
      "size": [315, 58],
      "order": 8,
      "mode": 0,
      "inputs": [{"name": "model", "type": "MODEL", "link": 112}],
      "outputs": [{"name": "MODEL", "type": "MODEL", "slot_index": 0, "links": [123]}],
      "widgets_values": [8]
    },
    {
      "id": 50,
      "type": "WanImageToVideo",
      "pos": [491, 617],
      "size": [342, 210],
      "order": 9,
      "mode": 0,
      "inputs": [
        {"name": "positive", "type": "CONDITIONING", "link": 97},
        {"name": "negative", "type": "CONDITIONING", "link": 98},
        {"name": "vae", "type": "VAE", "link": 99},
        {"name": "clip_vision_output", "type": "CLIP_VISION_OUTPUT", "link": null},
        {"name": "start_image", "type": "IMAGE", "link": 126}
      ],
      "outputs": [
        {"name": "positive", "type": "CONDITIONING", "slot_index": 0, "links": [118, 121]},
        {"name": "negative", "type": "CONDITIONING", "slot_index": 1, "links": [119, 122]},
        {"name": "latent", "type": "LATENT", "slot_index": 2, "links": [120]}
      ],
      "widgets_values": [832, 480, 81, 1]
    },
    {
      "id": 57,
      "type": "KSamplerAdvanced",
      "pos": [893, -29],
      "size": [304, 334],
      "order": 10,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 125},
        {"name": "positive", "type": "CONDITIONING", "link": 118},
        {"name": "negative", "type": "CONDITIONING", "link": 119},
        {"name": "latent_image", "type": "LATENT", "link": 120}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "slot_index": 0, "links": [113]}],
      "widgets_values": ["enable", 42, "fixed", 20, 3.5, "euler", "simple", 0, 10, "enable"]
    },
    {
      "id": 58,
      "type": "KSamplerAdvanced",
      "pos": [1262, -26],
      "size": [304, 334],
      "order": 11,
      "mode": 0,
      "inputs": [
        {"name": "model", "type": "MODEL", "link": 123},
        {"name": "positive", "type": "CONDITIONING", "link": 121},
        {"name": "negative", "type": "CONDITIONING", "link": 122},
        {"name": "latent_image", "type": "LATENT", "link": 113}
      ],
      "outputs": [{"name": "LATENT", "type": "LATENT", "slot_index": 0, "links": [124]}],
      "widgets_values": ["disable", 0, "fixed", 20, 3.5, "euler", "simple", 10, 10000, "disable"]
    },
    {
      "id": 8,
      "type": "VAEDecode",
      "pos": [1590, -20],
      "size": [210, 46],
      "order": 12,
      "mode": 0,
      "inputs": [
        {"name": "samples", "type": "LATENT", "link": 124},
        {"name": "vae", "type": "VAE", "link": 76}
      ],
      "outputs": [{"name": "IMAGE", "type": "IMAGE", "slot_index": 0, "links": [56]}]
    },
    {
      "id": 65,
      "type": "VHS_VideoCombine",
      "title": "Save MP4",
      "pos": [1820, -20],
      "size": [344, 290],
      "order": 13,
      "mode": 0,
      "inputs": [
        {"name": "images", "type": "IMAGE", "link": 56},
        {"name": "audio", "type": "AUDIO", "link": null},
        {"name": "meta_batch", "type": "VHS_BatchManager", "link": null}
      ],
      "outputs": [
        {"name": "Filenames", "type": "VHS_FILENAMES", "links": null}
      ],
      "widgets_values": [24, true, "kika_ep1/kika", "video/h264-mp4", "", "default", false, false, 0, false, "", ""]
    }
  ],
  "links": [
    [56, 8, 0, 65, 0, "IMAGE"],
    [74, 38, 0, 6, 0, "CLIP"],
    [75, 38, 0, 7, 0, "CLIP"],
    [76, 39, 0, 8, 1, "VAE"],
    [97, 6, 0, 50, 0, "CONDITIONING"],
    [98, 7, 0, 50, 1, "CONDITIONING"],
    [99, 39, 0, 50, 2, "VAE"],
    [110, 37, 0, 54, 0, "MODEL"],
    [112, 56, 0, 55, 0, "MODEL"],
    [113, 57, 0, 58, 3, "LATENT"],
    [118, 50, 0, 57, 1, "CONDITIONING"],
    [119, 50, 1, 57, 2, "CONDITIONING"],
    [120, 50, 2, 57, 3, "LATENT"],
    [121, 50, 0, 58, 1, "CONDITIONING"],
    [122, 50, 1, 58, 2, "CONDITIONING"],
    [123, 55, 0, 58, 0, "MODEL"],
    [124, 58, 0, 8, 0, "LATENT"],
    [125, 54, 0, 57, 0, "MODEL"],
    [126, 52, 0, 50, 4, "IMAGE"]
  ],
  "groups": [],
  "config": {},
  "extra": {},
  "version": 0.4
}
WORKFLOW_EOF

echo "  ✅ Workflow: input/kika_ep1/wan22_i2v_14B_kika.json"

# ------------------------------------------------------------
# PASSO 6 — Lançar ComfyUI
# ------------------------------------------------------------
echo ""
echo "[6/6] A lançar ComfyUI..."

cd "$COMFY"

python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --fp16-vae \
    --normalvram \
    --disable-smart-memory \
    &

sleep 15

echo ""
echo "============================================================"
echo "  ✅ SETUP COMPLETO — PROJECTO KIKA"
echo "============================================================"
echo ""
echo "  ComfyUI: http://localhost:8188"
echo ""
echo "  WORKFLOW:"
echo "  Open → input/kika_ep1/wan22_i2v_14B_kika.json"
echo ""
echo "  ANTES DE GERAR:"
echo "  1. Faz upload da imagem da Kika (PNG)"
echo "  2. No nó LoadImage: selecciona kika.png"
echo "  3. Edita o Positive Prompt"
echo "  4. Queue Prompt (Ctrl+Enter)"
echo ""
echo "  SETTINGS PADRÃO:"
echo "  Resolução: 832x480 | Frames: 81 | FPS: 24"
echo "  Para 720p: muda para 1280x720 (mais lento)"
echo ""
echo "  OUTPUT → output/kika_ep1/kika_XXXXX.mp4"
echo "  LOG    → $LOG"
echo "============================================================"

wait
