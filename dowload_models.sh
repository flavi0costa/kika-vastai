#!/bin/bash

cd /workspace/ComfyUI

echo "=== DOWNLOAD WAN FP16 ==="

# TEXT ENCODER
wget -nc -P models/text_encoders \
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5_xxl_fp16.safetensors

# VAE
wget -nc -P models/vae \
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/wan_2.1_vae.safetensors

# WAN FP16 LOW NOISE
wget -nc -P models/diffusion_models \
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/wan2.2_i2v_low_noise_14B_fp16.safetensors

# WAN FP16 HIGH NOISE
wget -nc -P models/diffusion_models \
https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/wan2.2_i2v_high_noise_14B_fp16.safetensors

echo "=== DOWNLOAD DONE ==="