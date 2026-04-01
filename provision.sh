#!/bin/bash
# ============================================================
#  PROJECTO KIKA \u2014 Wan 2.2 I2V 14B FP8
#  Vast.ai A100 40GB | ComfyUI fresh clone
#  https://github.com/flavi0costa/kika-vastai
# ============================================================

LOG="/workspace/provision.log"
exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo "  PROJECTO KIKA \u2014 Wan 2.2 I2V 14B FP8"
echo "  $(date)"
echo "============================================================"

set -e  # Para em qualquer erro

COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
HF="https://huggingface.co"

# ------------------------------------------------------------
# PASSO 1 \u2014 ComfyUI clone fresco (NUNCA git pull)
# ------------------------------------------------------------
echo ""
echo "[1/6] Clone fresco ComfyUI..."

cd /workspace
rm -rf "$COMFY"
git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY"
cd "$COMFY"
pip install -q -r requirements.txt

echo "  \u2705 ComfyUI $(git rev-parse --short HEAD)"

# ------------------------------------------------------------
# PASSO 2 \u2014 Custom nodes essenciais
# ------------------------------------------------------------
echo ""
echo "[2/6] Custom nodes..."

cd "$COMFY/custom_nodes"

# VideoHelperSuite \u2014 obrigat\u00f3rio para guardar MP4
if [ ! -d "ComfyUI-VideoHelperSuite" ]; then
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
    pip install -q -r ComfyUI-VideoHelperSuite/requirements.txt
fi

echo "  \u2705 VideoHelperSuite pronto"

# ------------------------------------------------------------
# PASSO 3 \u2014 Criar estrutura de pastas
# ------------------------------------------------------------
echo ""
echo "[3/6] Criar pastas..."

mkdir -p "$MODELS/diffusion_models"
mkdir -p "$MODELS/text_encoders"
mkdir -p "$MODELS/vae"
mkdir -p "$MODELS/clip_vision"
mkdir -p "$COMFY/input/kika_ep1"
mkdir -p "$COMFY/output/kika_ep1"

echo "  \u2705 Pastas criadas"

# ------------------------------------------------------------
# PASSO 4 \u2014 Download modelos Wan 2.2 I2V 14B FP8
# Fonte: Comfy-Org/Wan_2.2_ComfyUI_Repackaged (oficial)
# ------------------------------------------------------------
echo ""
echo "[4/6] Download modelos Wan 2.2..."
echo "  \u26a0\ufe0f  ~38GB total \u2014 pode demorar 15-30 min"

download() {
    local URL="$1"
    local DEST="$2"
    local NAME=$(basename "$DEST")

    if [ -f "$DEST" ] && [ $(stat -c%s "$DEST") -gt 1000000 ]; then
        echo "  \u23ed\ufe0f  $NAME j\u00e1 existe \u2014 skip"
        return 0
    fi

    echo "  \u2b07\ufe0f  $NAME..."
    wget -q --show-progress -c "$URL" -O "$DEST"

    if [ -f "$DEST" ] && [ $(stat -c%s "$DEST") -gt 1000000 ]; then
        SIZE=$(du -sh "$DEST" | cut -f1)
        echo "  \u2705 $NAME (${SIZE})"
    else
        echo "  \u274c ERRO: $NAME falhou"
        exit 1
    fi
}

# Diffusion models \u2014 I2V high + low noise (ambos obrigat\u00f3rios)
download \
    "$HF/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
    "$MODELS/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"

download \
    "$HF/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
    "$MODELS/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"

# Text encoder UMT5 FP8
download \
    "$HF/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "$MODELS/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# VAE
download \
    "$HF/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
    "$MODELS/vae/wan_2.1_vae.safetensors"

# CLIP Vision (de Wan 2.1 \u2014 compat\u00edvel com 2.2)
download \
    "$HF/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
    "$MODELS/clip_vision/clip_vision_h.safetensors"

echo ""
echo "  \ud83d\udce6 Modelos descarregados:"
du -sh "$MODELS/diffusion_models/"*.safetensors 2>/dev/null | sort -h
du -sh "$MODELS/text_encoders/"*.safetensors 2>/dev/null
du -sh "$MODELS/vae/"*.safetensors 2>/dev/null
du -sh "$MODELS/clip_vision/"*.safetensors 2>/dev/null

# ------------------------------------------------------------
# PASSO 5 \u2014 Verificar espa\u00e7o em disco
# ------------------------------------------------------------
echo ""
echo "[5/6] Verificar disco..."

LIVRE=$(df -BG /workspace | awk 'NR==2{print $4}' | tr -d 'G')
echo "  Espa\u00e7o livre: ${LIVRE}GB"

if [ "$LIVRE" -lt 5 ]; then
    echo "  \u26a0\ufe0f  AVISO: Menos de 5GB livres \u2014 considera disco maior"
fi

echo "  \u2705 Disco OK"

# ------------------------------------------------------------
# PASSO 6 \u2014 Lan\u00e7ar ComfyUI
# ------------------------------------------------------------
echo ""
echo "[6/6] A lan\u00e7ar ComfyUI..."

cd "$COMFY"

# Flags optimizadas para A100 40GB
python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --fp16-vae \