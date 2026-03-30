#!/bin/bash
# ============================================================
# PROJECTO KIKA — Vast.ai Provisioning Script
# Wan 2.2 I2V 14B FP8 | RTX 3090 24GB | ComfyUI
# ============================================================
# COMO USAR NO VAST.AI:
# Template: vastai/comfy
# Environment Variable:
#   PROVISIONING_SCRIPT=https://raw.githubusercontent.com/flavi0costa/kika-vastai/main/provision.sh
# ============================================================

LOG="/workspace/provision.log"
exec > >(tee -a "$LOG") 2>&1

echo "================================================"
echo "  PROJECTO KIKA — Setup Wan 2.2 I2V"
echo "  $(date)"
echo "================================================"

# Localizar ComfyUI
if [ -d "/workspace/ComfyUI" ]; then
    COMFYUI_DIR="/workspace/ComfyUI"
elif [ -d "/comfyui" ]; then
    COMFYUI_DIR="/comfyui"
else
    echo "❌ ComfyUI não encontrado"
    exit 1
fi
echo "✅ ComfyUI em: $COMFYUI_DIR"

# ------------------------------------------------------------
# PASSO 1 — Actualizar ComfyUI
# Necessário para nós nativos Wan 2.2:
#   EmptyWanLatentVideo, WanImageToVideoCondition
# ------------------------------------------------------------
echo ""
echo "[1/4] A actualizar ComfyUI..."
cd "$COMFYUI_DIR"
git pull origin master 2>/dev/null || git pull origin main 2>/dev/null || true
pip install -q -r requirements.txt
echo "✅ ComfyUI actualizado"

# ------------------------------------------------------------
# PASSO 2 — Instalar VideoHelperSuite
# Necessário para guardar vídeo em MP4 (VHS_VideoCombine)
# Único custom node necessário — tudo o resto é nativo
# ------------------------------------------------------------
echo ""
echo "[2/4] A instalar VideoHelperSuite..."
cd "$COMFYUI_DIR/custom_nodes"

if [ ! -d "ComfyUI-VideoHelperSuite" ]; then
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
    cd ComfyUI-VideoHelperSuite
    pip install -q -r requirements.txt 2>/dev/null || true
    cd ..
    echo "✅ VideoHelperSuite instalado"
else
    cd ComfyUI-VideoHelperSuite
    git pull 2>/dev/null || true
    cd ..
    echo "✅ VideoHelperSuite já existe"
fi

# ------------------------------------------------------------
# PASSO 3 — Descarregar modelos Wan 2.2 I2V 14B FP8
# Fonte: Comfy-Org/Wan_2.2_ComfyUI_Repackaged (oficial)
# Ficheiros em split_files/ — nomes verificados
# ------------------------------------------------------------
echo ""
echo "[3/4] A descarregar modelos Wan 2.2 I2V 14B FP8..."
echo "      (~34GB total — pode demorar 15-20 min)"
cd "$COMFYUI_DIR"

mkdir -p models/diffusion_models
mkdir -p models/text_encoders
mkdir -p models/clip_vision
mkdir -p models/vae

REPO="Comfy-Org/Wan_2.2_ComfyUI_Repackaged"

download_model() {
    local DEST_FILE="$1"
    local HF_PATH="$2"
    local DEST_DIR="$3"

    if [ -f "${DEST_DIR}/${DEST_FILE}" ]; then
        SIZE=$(du -sh "${DEST_DIR}/${DEST_FILE}" | cut -f1)
        echo "  ✅ ${DEST_FILE} já existe (${SIZE})"
        return
    fi

    echo "  → A descarregar ${DEST_FILE}..."
    python3 - <<PYEOF
from huggingface_hub import hf_hub_download
import shutil, os

path = hf_hub_download(
    repo_id='${REPO}',
    filename='${HF_PATH}',
    local_dir='/tmp/wan_dl',
    resume_download=True
)
os.makedirs('${DEST_DIR}', exist_ok=True)
shutil.move(path, '${DEST_DIR}/${DEST_FILE}')
print('  ✅ ${DEST_FILE}')
PYEOF
}

# Modelo I2V high noise (~13GB)
download_model \
    "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
    "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
    "models/diffusion_models"

# Modelo I2V low noise (~13GB)
download_model \
    "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
    "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
    "models/diffusion_models"

# Text encoder UMT5 FP8 (~6.7GB)
download_model \
    "umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "models/text_encoders"

# CLIP Vision (~630MB)
download_model \
    "clip_vision_h.safetensors" \
    "split_files/clip_vision/clip_vision_h.safetensors" \
    "models/clip_vision"

# VAE (~420MB)
download_model \
    "wan_2.1_vae.safetensors" \
    "split_files/vae/wan_2.1_vae.safetensors" \
    "models/vae"

# Verificação final
echo ""
echo "  Verificação de integridade:"
FAIL=0
for f in \
    "models/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
    "models/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
    "models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "models/clip_vision/clip_vision_h.safetensors" \
    "models/vae/wan_2.1_vae.safetensors"; do
    if [ -f "$f" ]; then
        SIZE=$(du -sh "$f" | cut -f1)
        echo "  ✅ $(basename $f) (${SIZE})"
    else
        echo "  ❌ FALTA: $f"
        FAIL=1
    fi
done

if [ $FAIL -eq 1 ]; then
    echo "❌ Modelos em falta — verifica o log em $LOG"
    exit 1
fi

echo "✅ Todos os modelos prontos"

# ------------------------------------------------------------
# PASSO 4 — Criar pasta input e guia de prompts
# ------------------------------------------------------------
echo ""
echo "[4/4] A preparar pastas..."
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

NÓS USADOS (todos nativos ou instalados):
  ✅ UNETLoader          — nativo ComfyUI
  ✅ CLIPLoader          — nativo ComfyUI
  ✅ VAELoader           — nativo ComfyUI
  ✅ CLIPVisionLoader    — nativo ComfyUI
  ✅ WanImageToVideoCondition — nativo ComfyUI
  ✅ EmptyWanLatentVideo — nativo ComfyUI
  ✅ KSampler            — nativo ComfyUI
  ✅ VAEDecode           — nativo ComfyUI
  ✅ VHS_VideoCombine    — VideoHelperSuite (instalado)

MODELOS CARREGADOS:
  high_noise: wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors
  low_noise:  wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors
  clip:       umt5_xxl_fp8_e4m3fn_scaled.safetensors
  clip_vision: clip_vision_h.safetensors
  vae:        wan_2.1_vae.safetensors

============================================================
CENA 1 — Kika entra na cozinha

PROMPT POSITIVO:
A cheerful young girl chef with blonde curly hair and green
eyes, wearing white chef coat with red buttons and blue apron,
runs joyfully into a colorful cartoon kitchen, stops in center,
opens her arms wide with a big happy smile, welcoming the viewer.
Smooth natural movement, Pixar 3D animation style, warm lighting.

PROMPT NEGATIVO:
blurry, low quality, distorted face, extra limbs, ugly,
realistic photo, dark, horror, watermark, text

SETTINGS:
  Steps: 20 | CFG: 6.0 | Resolução: 1280x720 | Frames: 81
============================================================
EOF

echo "✅ Guia criado em input/kika_ep1/COMO_USAR.txt"

echo ""
echo "================================================"
echo "  SETUP COMPLETO! ✅"
echo "  $(date)"
echo "================================================"
echo ""
echo "  NO BROWSER:"
echo "  Workflow → Browse Templates → Video → Wan2.2 14B I2V"
echo ""
echo "  Log completo: $LOG"
echo "================================================"
