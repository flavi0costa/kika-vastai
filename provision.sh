#!/bin/bash
# ============================================================
# PROJECTO KIKA — Vast.ai Provisioning Script v2
# Wan 2.2 I2V 14B FP8 | RTX 3090 24GB | ComfyUI
# ============================================================
# VAST.AI SETUP:
# Template: vastai/comfy v0.18.2-cuda-12.9-py312
# Disco: 80GB
# Env var:
#   PROVISIONING_SCRIPT=https://raw.githubusercontent.com/flavi0costa/kika-vastai/main/provision.sh
# ============================================================

LOG="/workspace/provision.log"
exec > >(tee -a "$LOG") 2>&1

echo "================================================"
echo "  PROJECTO KIKA — Setup Wan 2.2 I2V v2"
echo "  $(date)"
echo "================================================"

COMFYUI_DIR="/workspace/ComfyUI"

# ------------------------------------------------------------
# PASSO 1 — Clone fresco do ComfyUI
# CORRECÇÃO: git pull não resolve erro CFG no template Wan 2.2
# Clone fresco confirmado como solução
# ------------------------------------------------------------
echo ""
echo "[1/5] Clone fresco ComfyUI..."
cd /workspace

# Guarda modelos se já existirem (2ª sessão)
if [ -d "$COMFYUI_DIR/models" ]; then
    echo "  → Modelos existentes encontrados, a preservar..."
    cp -r "$COMFYUI_DIR/models" /tmp/models_bak
fi

rm -rf "$COMFYUI_DIR"
git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
cd "$COMFYUI_DIR"
pip install -q -r requirements.txt

# Restaura modelos
if [ -d "/tmp/models_bak" ]; then
    cp -r /tmp/models_bak/* "$COMFYUI_DIR/models/" 2>/dev/null || true
    rm -rf /tmp/models_bak
fi

echo "✅ ComfyUI pronto (clone fresco)"

# ------------------------------------------------------------
# PASSO 2 — VideoHelperSuite
# Necessário para guardar MP4 (VHS_VideoCombine)
# ------------------------------------------------------------
echo ""
echo "[2/5] A instalar VideoHelperSuite..."
cd "$COMFYUI_DIR/custom_nodes"

if [ ! -d "ComfyUI-VideoHelperSuite" ]; then
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
    cd ComfyUI-VideoHelperSuite
    pip install -q -r requirements.txt 2>/dev/null || true
    cd ..
fi
echo "✅ VideoHelperSuite pronto"

# ------------------------------------------------------------
# PASSO 3 — Modelos Wan 2.2 I2V 14B FP8
# Todos os ficheiros necessários incluindo LoRAs do template
# ------------------------------------------------------------
echo ""
echo "[3/5] A descarregar modelos (~38GB)..."
cd "$COMFYUI_DIR"

mkdir -p models/diffusion_models
mkdir -p models/text_encoders
mkdir -p models/clip_vision
mkdir -p models/vae
mkdir -p models/loras

dl() {
    local FILE="$1"
    local HF_PATH="$2"
    local DEST="$3"
    local REPO="${4:-Comfy-Org/Wan_2.2_ComfyUI_Repackaged}"

    if [ -f "${DEST}/${FILE}" ]; then
        echo "  ✅ ${FILE} já existe"
        return
    fi
    echo "  → ${FILE}..."
    python3 -c "
from huggingface_hub import hf_hub_download
import shutil, os
p = hf_hub_download(repo_id='${REPO}', filename='${HF_PATH}', local_dir='/tmp/dl', resume_download=True)
os.makedirs('${DEST}', exist_ok=True)
shutil.move(p, '${DEST}/${FILE}')
print('  done')
"
}

# Modelos principais I2V (~13GB cada)
dl "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
   "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
   "models/diffusion_models"

dl "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
   "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
   "models/diffusion_models"

# Text encoder (~6.7GB)
dl "umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
   "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
   "models/text_encoders"

# CLIP Vision (~1.2GB) — vem do repo Wan 2.1
dl "clip_vision_h.safetensors" \
   "split_files/clip_vision/clip_vision_h.safetensors" \
   "models/clip_vision" \
   "Comfy-Org/Wan_2.1_ComfyUI_repackaged"

# VAE (~420MB)
dl "wan_2.1_vae.safetensors" \
   "split_files/vae/wan_2.1_vae.safetensors" \
   "models/vae"

# LoRAs (~1.1GB cada) — necessários para template oficial
dl "wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors" \
   "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors" \
   "models/loras"

dl "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
   "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
   "models/loras"

# Limpar temporários
rm -rf /tmp/dl 2>/dev/null || true

# Verificação
echo ""
echo "  Verificação:"
FAIL=0
for f in \
    "models/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
    "models/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
    "models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "models/clip_vision/clip_vision_h.safetensors" \
    "models/vae/wan_2.1_vae.safetensors" \
    "models/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors" \
    "models/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"; do
    if [ -f "$f" ]; then
        SIZE=$(du -sh "$f" | cut -f1)
        echo "  ✅ $(basename $f) (${SIZE})"
    else
        echo "  ❌ FALTA: $f"
        FAIL=1
    fi
done

if [ $FAIL -eq 1 ]; then
    echo "❌ Modelos em falta — verifica $LOG"
    exit 1
fi
echo "✅ Todos os modelos prontos"

# ------------------------------------------------------------
# PASSO 4 — Espaço em disco
# ------------------------------------------------------------
echo ""
echo "[4/5] Espaço em disco:"
df -h /workspace

# ------------------------------------------------------------
# PASSO 5 — Pastas e guia
# ------------------------------------------------------------
echo ""
echo "[5/5] A preparar pastas..."
mkdir -p "$COMFYUI_DIR/input/kika_ep1"
mkdir -p "$COMFYUI_DIR/output/kika_ep1"

cat > "$COMFYUI_DIR/input/kika_ep1/COMO_USAR.txt" << 'EOF'
============================================================
PROJECTO KIKA EP1 — GUIA RÁPIDO
============================================================
1. Workflow → Browse Templates → Video → "Wan2.2 14B I2V"
2. Upload da imagem da Kika no nó "Load Image"
3. Edita o prompt positivo
4. Queue Prompt

CENA 1 — Kika entra na cozinha
PROMPT POSITIVO:
A cheerful young girl chef with blonde curly hair and green eyes,
wearing white chef coat with red buttons and blue apron, runs
joyfully into a colorful cartoon kitchen, stops in center, opens
her arms wide with a big happy smile. Smooth natural cartoon
movement, Pixar 3D animation style, warm lighting.

PROMPT NEGATIVO:
blurry, low quality, distorted face, extra limbs, ugly,
realistic photo, dark, horror, watermark, text, static, frozen

SETTINGS: Steps 20 | CFG 6.0 | 1280x720 | 81 frames
============================================================
EOF

echo ""
echo "================================================"
echo "  SETUP COMPLETO ✅"
echo "  $(date)"
echo "================================================"
echo "  Workflow → Browse Templates → Video → Wan2.2 14B I2V"
echo "  Log: $LOG"
echo "================================================"
