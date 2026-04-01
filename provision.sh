#!/bin/bash

LOG="/workspace/provision.log"
exec > >(tee -a "$LOG") 2>&1

echo "================================================"
echo "  PROJECTO KIKA — Setup LTX 2.3 I2V"
echo "  $(date)"
echo "================================================"

COMFYUI_DIR="/workspace/ComfyUI"

# ------------------------------------------------------------
# PASSO 1 — ComfyUI fresco (igual ao teu)
# ------------------------------------------------------------
echo ""
echo "[1/5] Clone fresco ComfyUI..."
cd /workspace

if [ -d "$COMFYUI_DIR/models" ]; then
    cp -r "$COMFYUI_DIR/models" /tmp/models_bak
fi

rm -rf "$COMFYUI_DIR"
git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
cd "$COMFYUI_DIR"
pip install -q -r requirements.txt

if [ -d "/tmp/models_bak" ]; then
    cp -r /tmp/models_bak/* "$COMFYUI_DIR/models/" 2>/dev/null || true
    rm -rf /tmp/models_bak
fi

echo "✅ ComfyUI pronto"

# ------------------------------------------------------------
# PASSO 2 — Nodes necessários
# ------------------------------------------------------------
echo ""
echo "[2/5] Instalar nodes..."

cd "$COMFYUI_DIR/custom_nodes"

git clone https://github.com/Lightricks/ComfyUI-LTXVideo || true
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite || true

echo "✅ Nodes prontos"

# ------------------------------------------------------------
# PASSO 3 — MODELO LTX
# ------------------------------------------------------------
echo ""
echo "[3/5] Download modelo LTX..."

cd "$COMFYUI_DIR/models/checkpoints"

wget -c https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltx-video.safetensors \
     -O ltx-video.safetensors

if [ -f "ltx-video.safetensors" ]; then
    SIZE=$(du -sh ltx-video.safetensors | cut -f1)
    echo "  ✅ Modelo LTX (${SIZE})"
else
    echo "  ❌ ERRO download modelo"
    exit 1
fi

# ------------------------------------------------------------
# PASSO 4 — Pastas projeto
# ------------------------------------------------------------
echo ""
echo "[4/5] Preparar pastas..."

mkdir -p "$COMFYUI_DIR/input/kika_ep1"
mkdir -p "$COMFYUI_DIR/output/kika_ep1"

# ------------------------------------------------------------
# PASSO 5 — GUIA
# ------------------------------------------------------------
echo ""
echo "[5/5] Criar guia..."

cat > "$COMFYUI_DIR/input/kika_ep1/COMO_USAR.txt" << 'EOF'
============================================================
PROJECTO KIKA — LTX VIDEO
============================================================

Workflow:
Load Image → LTX Video → Save Video

SETTINGS:
Frames: 24
FPS: 12
Duration: ~2s

PROMPT BASE:
subtle natural motion, small movement, stable identity,
no deformation, no character change

NOTA:
menos movimento = melhor consistência

============================================================
EOF

echo ""
echo "================================================"
echo "  SETUP LTX COMPLETO ✅"
echo "================================================"
echo "ComfyUI pronto com LTX"
echo "Log: $LOG"
echo "================================================"