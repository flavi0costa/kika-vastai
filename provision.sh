#!/bin/bash
# ============================================================
#  PROJECTO KIKA — Wan 2.2 I2V 14B FP8 + LoRA LightX2V
#  Vast.ai A100 40GB | ComfyUI fresh clone
#  github.com/flavi0costa/kika-vastai
# ============================================================

LOG="/workspace/provision.log"
exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo "  PROJECTO KIKA — Wan 2.2 I2V 14B FP8 + LightX2V"
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
# PASSO 2 — Custom nodes
# ------------------------------------------------------------
echo ""
echo "[2/6] Custom nodes..."

cd "$COMFY/custom_nodes"

# VideoHelperSuite — guardar MP4
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
pip install -q -r ComfyUI-VideoHelperSuite/requirements.txt

# KJNodes — PathchSageAttentionKJ + GetImageSizeAndCount + INTConstant
git clone https://github.com/kijai/ComfyUI-KJNodes.git
pip install -q -r ComfyUI-KJNodes/requirements.txt

# Crystools — Switch any
git clone https://github.com/crystian/ComfyUI-Crystools.git
pip install -q -r ComfyUI-Crystools/requirements.txt

# LayerStyle — BooleanOperator
git clone https://github.com/chflame163/ComfyUI_LayerStyle.git
pip install -q -r ComfyUI_LayerStyle/requirements.txt 2>/dev/null || true

echo "  ✅ Nodes prontos"

# ------------------------------------------------------------
# PASSO 3 — Estrutura de pastas
# ------------------------------------------------------------
echo ""
echo "[3/6] Criar pastas..."

mkdir -p "$MODELS/diffusion_models"
mkdir -p "$MODELS/text_encoders"
mkdir -p "$MODELS/vae"
mkdir -p "$MODELS/clip_vision"
mkdir -p "$MODELS/loras"
mkdir -p "$COMFY/input/kika_ep1"
mkdir -p "$COMFY/output/kika_ep1"

echo "  ✅ Pastas criadas"

# ------------------------------------------------------------
# PASSO 4 — Download modelos
# ------------------------------------------------------------
echo ""
echo "[4/6] Download modelos (~40GB)..."

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

# Diffusion models
download "$BASE/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
         "$MODELS/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"

download "$BASE/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
         "$MODELS/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"

# Text encoder
download "$BASE/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
         "$MODELS/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# VAE
download "$BASE/vae/wan_2.1_vae.safetensors" \
         "$MODELS/vae/wan_2.1_vae.safetensors"

# CLIP Vision
download "$BASE/clip_vision/clip_vision_h.safetensors" \
         "$MODELS/clip_vision/clip_vision_h.safetensors"

# LoRA LightX2V — necessária para 8 steps
download "$HF/Kijai/WanVideo_stuff/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors" \
         "$MODELS/loras/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors"

echo ""
echo "  📦 Total:"
du -sh "$MODELS"/*/ 2>/dev/null

# ------------------------------------------------------------
# PASSO 5 — Workflow Wan22I2V_Native
# ------------------------------------------------------------
echo ""
echo "[5/6] Copiar workflow..."

cat > "$COMFY/input/kika_ep1/Wan22I2V_Kika.json" << 'WORKFLOW_EOF'
{
  "id": "add64467-4242-4a60-a9dd-d7885e4d1ed8",
  "revision": 0,
  "last_node_id": 28,
  "last_link_id": 44,
  "nodes": [
    {
      "id": 1,
      "type": "CLIPLoader",
      "pos": [
        -357.7915954589844,
        372.80908203125
      ],
      "size": [
        346.391845703125,
        106
      ],
      "flags": {},
      "order": 0,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "CLIP",
          "type": "CLIP",
          "slot_index": 0,
          "links": [
            12,
            19
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "CLIPLoader",
        "models": [
          {
            "name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors",
            "url": "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors",
            "directory": "text_encoders"
          }
        ]
      },
      "widgets_values": [
        "umt5_xxl_fp8_e4m3fn_scaled.safetensors",
        "wan",
        "default"
      ]
    },
    {
      "id": 6,
      "type": "CLIPTextEncode",
      "pos": [
        588.3845825195312,
        630.2520141601562
      ],
      "size": [
        425.27801513671875,
        180.6060791015625
      ],
      "flags": {},
      "order": 7,
      "mode": 0,
      "inputs": [
        {
          "name": "clip",
          "type": "CLIP",
          "link": 12
        }
      ],
      "outputs": [
        {
          "name": "CONDITIONING",
          "type": "CONDITIONING",
          "slot_index": 0,
          "links": [
            16
          ]
        }
      ],
      "title": "CLIP Text Encode (Negative Prompt)",
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "CLIPTextEncode"
      },
      "widgets_values": [
        "色调艳丽，过曝，静态，细节模糊不清，字幕，风格，作品，画作，画面，静止，整体发灰，最差质量，低质量，JPEG压缩残留，丑陋的，残缺的，多余的手指，画得不好的手部，画得不好的脸部，畸形的，毁容的，形态畸形的肢体，手指融合，静止不动的画面，杂乱的背景，三条腿，背景人很多，倒着走"
      ],
      "color": "#322",
      "bgcolor": "#533"
    },
    {
      "id": 7,
      "type": "VAELoader",
      "pos": [
        -356.6561584472656,
        533.54443359375
      ],
      "size": [
        344.731689453125,
        59.98149108886719
      ],
      "flags": {},
      "order": 1,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "VAE",
          "type": "VAE",
          "slot_index": 0,
          "links": [
            10,
            17
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "VAELoader",
        "models": [
          {
            "name": "wan_2.1_vae.safetensors",
            "url": "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors",
            "directory": "vae"
          }
        ]
      },
      "widgets_values": [
        "wan_2.1_vae.safetensors"
      ]
    },
    {
      "id": 10,
      "type": "WanImageToVideo",
      "pos": [
        618.3845825195312,
        910.2520141601562
      ],
      "size": [
        342.5999755859375,
        210
      ],
      "flags": {},
      "order": 19,
      "mode": 0,
      "inputs": [
        {
          "name": "positive",
          "type": "CONDITIONING",
          "link": 15
        },
        {
          "name": "negative",
          "type": "CONDITIONING",
          "link": 16
        },
        {
          "name": "vae",
          "type": "VAE",
          "link": 17
        },
        {
          "name": "clip_vision_output",
          "shape": 7,
          "type": "CLIP_VISION_OUTPUT",
          "link": null
        },
        {
          "name": "start_image",
          "shape": 7,
          "type": "IMAGE",
          "link": 18
        },
        {
          "name": "width",
          "type": "INT",
          "widget": {
            "name": "width"
          },
          "link": 43
        },
        {
          "name": "height",
          "type": "INT",
          "widget": {
            "name": "height"
          },
          "link": 44
        }
      ],
      "outputs": [
        {
          "name": "positive",
          "type": "CONDITIONING",
          "slot_index": 0,
          "links": [
            2,
            6
          ]
        },
        {
          "name": "negative",
          "type": "CONDITIONING",
          "slot_index": 1,
          "links": [
            3,
            7
          ]
        },
        {
          "name": "latent",
          "type": "LATENT",
          "slot_index": 2,
          "links": [
            8
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "WanImageToVideo"
      },
      "widgets_values": [
        1280,
        720,
        121,
        1
      ]
    },
    {
      "id": 11,
      "type": "UNETLoader",
      "pos": [
        -362.4308166503906,
        111.7649154663086
      ],
      "size": [
        346.7470703125,
        82
      ],
      "flags": {},
      "order": 2,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "slot_index": 0,
          "links": [
            30
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "UNETLoader",
        "models": [
          {
            "name": "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors",
            "url": "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors",
            "directory": "diffusion_models"
          }
        ]
      },
      "widgets_values": [
        "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors",
        "fp8_e4m3fn_fast"
      ]
    },
    {
      "id": 4,
      "type": "VAEDecode",
      "pos": [
        1408.3846435546875,
        180.2520294189453
      ],
      "size": [
        210,
        46
      ],
      "flags": {},
      "order": 22,
      "mode": 0,
      "inputs": [
        {
          "name": "samples",
          "type": "LATENT",
          "link": 9
        },
        {
          "name": "vae",
          "type": "VAE",
          "link": 10
        }
      ],
      "outputs": [
        {
          "name": "IMAGE",
          "type": "IMAGE",
          "slot_index": 0,
          "links": [
            21
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "VAEDecode"
      },
      "widgets_values": []
    },
    {
      "id": 12,
      "type": "UNETLoader",
      "pos": [
        -361.95306396484375,
        240.7196044921875
      ],
      "size": [
        346.7470703125,
        82
      ],
      "flags": {},
      "order": 3,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "slot_index": 0,
          "links": [
            31
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "UNETLoader",
        "models": [
          {
            "name": "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors",
            "url": "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors",
            "directory": "diffusion_models"
          }
        ]
      },
      "widgets_values": [
        "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors",
        "fp8_e4m3fn_fast"
      ]
    },
    {
      "id": 8,
      "type": "ModelSamplingSD3",
      "pos": [
        808.3845825195312,
        150.2520294189453
      ],
      "size": [
        210,
        60
      ],
      "flags": {},
      "order": 15,
      "mode": 0,
      "inputs": [
        {
          "name": "model",
          "type": "MODEL",
          "link": 32
        }
      ],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "slot_index": 0,
          "links": [
            5
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "ModelSamplingSD3"
      },
      "widgets_values": [
        8.000000000000002
      ]
    },
    {
      "id": 9,
      "type": "ModelSamplingSD3",
      "pos": [
        808.3845825195312,
        280.25201416015625
      ],
      "size": [
        210,
        58
      ],
      "flags": {},
      "order": 16,
      "mode": 0,
      "inputs": [
        {
          "name": "model",
          "type": "MODEL",
          "link": 33
        }
      ],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "slot_index": 0,
          "links": [
            1
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfy-core",
        "ver": "0.3.45",
        "Node name for S&R": "ModelSamplingSD3"
      },
      "widgets_values": [
        8
      ]
    },
    {
      "id": 21,
      "type": "PathchSageAttentionKJ",
      "pos": [
        429.23577880859375,
        131.72811889648438
      ],
      "size": [
        270,
        58
      ],
      "flags": {},
      "order": 12,
      "mode": 0,
      "inputs": [
        {
          "name": "model",
          "type": "MODEL",
          "link": 26
        }
      ],
      "outputs": [
        {
          "name": "MODEL",
          "type": "MODEL",
          "links": [
            32
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfyui-kjnodes",
        "ver": "a6b867b63a29ca48ddb15c589e17a9f2d8530d57",
        "Node name for S&R": "PathchSageAttentionKJ"
      },
      "widgets_values": [
        "auto"
      ]
    },
    {
      "id": 24,
      "type": "Switch any [Crystools]",
      "pos": [
        262.2376708984375,
        815.71142578125
      ],
      "size": [
        270,
        78
      ],
      "flags": {},
      "order": 17,
      "mode": 0,
      "inputs": [
        {
          "name": "on_true",
          "type": "*",
          "link": 34
        },
        {
          "name": "on_false",
          "type": "*",
          "link": 35
        },
        {
          "name": "boolean",
          "type": "BOOLEAN",
          "widget": {
            "name": "boolean"
          },
          "link": 36
        }
      ],
      "outputs": [
        {
          "name": "*",
          "type": "*",
          "links": [
            43
          ]
        }
      ],
      "title": "Width Switch",
      "properties": {
        "cnr_id": "ComfyUI-Crystools",
        "ver": "1156ff983b635ef506e7b79659126837a1e9d275",
        "Node name for S&R": "Switch any [Crystools]"
      },
      "widgets_values": [
        true
      ]
    },
    {
      "id": 25,
      "type": "Switch any [Crystools]",
      "pos": [
        261.0787048339844,
        950.5501708984375
      ],
      "size": [
        270,
        78
      ],
      "flags": {},
      "order": 18,
      "mode": 0,
      "inputs": [
        {
          "name": "on_true",
          "type": "*",
          "link": 37
        },
        {
          "name": "on_false",
          "type": "*",
          "link": 38
        },
        {
          "name": "boolean",
          "type": "BOOLEAN",
          "widget": {
            "name": "boolean"
          },
          "link": 39
        }
      ],
      "outputs": [
        {
          "name": "*",
          "type": "*",
          "links": [
            44
          ]
        }
      ],
      "title": "Height Switch",
      "properties": {
        "cnr_id": "ComfyUI-Crystools",
        "ver": "1156ff983b635ef506e7b79659126837a1e9d275",
        "Node name for S&R": "Switch any [Crystools]"
      },
      "widgets_values": [
        true
      ]
    },
    {
      "id": 23,
      "type": "LayerUtility: BooleanOperator",
      "pos": [
        -94.2278823852539,
        813.4481811523438
      ],
      "size": [
        287.4371032714844,
        78
      ],
      "flags": {},
      "order": 14,
      "mode": 0,
      "inputs": [
        {
          "name": "a",
          "type": "*",
          "link": 41
        },
        {
          "name": "b",
          "type": "*",
          "link": 42
        }
      ],
      "outputs": [
        {
          "name": "output",
          "type": "BOOLEAN",
          "links": [
            36,
            39
          ]
        }
      ],
      "properties": {
        "cnr_id": "comfyui_layerstyle",
        "ver": "a46b1e6d26d45be9784c49f7065ba44700ef2b63",
        "Node name for S&R": "LayerUtility: BooleanOperator"
      },
      "widgets_values": [
        ">"
      ],
      "color": "rgba(38, 73, 116, 0.7)"
    },
    {
      "id": 28,
      "type": "GetImageSizeAndCount",
      "pos": [
        -334.1408996582031,
        809.514892578125
      ],
      "size": [
        190.86483764648438,
        86
      ],
      "flags": {},
      "order": 11,
      "mode": 0,
      "inputs": [
        {
          "name": "image",
          "type": "IMAGE",
          "link": 40
        }
      ],
      "outputs": [
        {
          "name": "image",
          "type": "IMAGE",
          "links": null
        },
        {
          "label": "720 width",
          "name": "width",
          "type": "INT",
          "links": [
            41
          ]
        },
        {
          "label": "1280 height",
          "name": "height",
          "type": "INT",
          "links": [
            42
          ]
        },
        {
          "label": "1 count",
          "name": "count",
          "type": "INT",
          "links": null
        }
      ],
      "properties": {
        "cnr_id": "comfyui-kjnodes",
        "ver": "a6b867b63a29ca48ddb15c589e17a9f2d8530d57",
        "Node name for S&R": "GetImageSizeAndCount"
      },
      "widgets_values": []
    },
    {
      "id": 26,
      "type": "INTConstant",
      "pos": [
        -653.9583129882812,
        577.2951049804688
      ],
      "size": [
        210,
        58
      ],
      "flags": {},
      "order": 4,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "value",
          "type": "INT",
          "links": [
            34,
            38
          ]
        }
      ],
      "title": "Long Side",
      "properties": {
        "cnr_id": "comfyui-kjnodes",
        "ver": "9682804efb2e7caeafcca9431c94a38163e8ceb8",
        "Node name for S&R": "INTConstant"
      },
      "widgets_values": [
        832
      ],
      "color": "#1b4669",
      "bgcolor": "#29699c"
    },
    {
      "id": 27,
      "type": "INTConstant",
      "pos": [
        -647.9121704101562,
        685.2836303710938
      ],
      "size": [
        210,
        58
      ],
      "flags": {},
      "order": 5,
      "mode": 0,
      "inputs": [],
      "outputs": [
        {
          "name": "value",
          "type": "INT",
          "links": [
            35,
            37
          ]
        }
      ],
      "title": "Short Side",
      "properties": {
        "cnr_id": "comfyui-kjnodes",
        "ver": "9682804efb2e7caeafcca9431c94a38163e8ceb8",
        "Node name for S&R": "INTCons