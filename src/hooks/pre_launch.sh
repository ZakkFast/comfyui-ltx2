# shellcheck shell=bash
# pre_launch hook for comfyui-ltx2. This file is SOURCED by the shared runtime.

if ! python3 -c "import kornia,sys; sys.exit(0 if kornia.__version__=='0.8.2' else 1)" 2>/dev/null; then
    echo "🔧 Pinning kornia==0.8.2 for ComfyUI-LTXVideo..."
    pip install "kornia==0.8.2" > /tmp/pip_kornia.log 2>&1 \
        || { echo "⚠️  kornia==0.8.2 install failed (see /tmp/pip_kornia.log); ComfyUI-LTXVideo nodes may not load."
             report_warn "kornia 0.8.2 pin failed; ComfyUI-LTXVideo nodes may not load"; }
fi

mkdir -p "$WORKFLOW_DIR/LTX-2.5" "$WORKFLOW_DIR/Community-LTX-2.3" "$PERSIST_ROOT/custom_nodes"

OFFICIAL_25="$COMFYUI_DIR/custom_nodes/ComfyUI-LTXVideo/example_workflows/2.5/LTX-2.5_T2V_I2V_Two_Stage_Distilled.json"
if [ -f "$OFFICIAL_25" ]; then
    cp -f "$OFFICIAL_25" "$WORKFLOW_DIR/LTX-2.5/LTX-2.5_T2V_I2V_Two_Stage_Distilled.json"
else
    echo "⚠️  Official LTX-2.5 two-stage workflow was not found in ComfyUI-LTXVideo"
    report_warn "Official LTX-2.5 two-stage workflow missing from ComfyUI-LTXVideo"
fi

COMMUNITY_MARKER="$WORKFLOW_DIR/Community-LTX-2.3/.stefan_v12_installed"
DEFAULT_COMMUNITY_URL="https://prompthero.com/api/ai-models/ltx-23-workflows--ltx-director-runexx-workflows-remade-by-stefan-falkok--nsfw-base-i2v-first-last-frame-controlnet-edit-add-audio--lipsync-foley-extended-video-2677668-download/ltx-23-workflows--ltx-director-runexx-workflows-remade-by-stefan-falkok--nsfw-base-i2v-first-last-frame-controlnet-edit-add-audio--lipsync-foley-extended-video-v12-ltx-director/file/2e1f7562-ed07-48a1-a305-cacecbde767d/download"
COMMUNITY_URL="${LTX23_WORKFLOW_PACK_URL:-$DEFAULT_COMMUNITY_URL}"
if [ ! -f "$COMMUNITY_MARKER" ]; then
    echo "📦 Installing LTX-2.3 community workflow pack..."
    rm -rf /tmp/ltx23-community /tmp/ltx23-community.zip
    mkdir -p /tmp/ltx23-community
    if curl -fL --retry 3 --retry-delay 2 "$COMMUNITY_URL" -o /tmp/ltx23-community.zip \
       && python3 -m zipfile -e /tmp/ltx23-community.zip /tmp/ltx23-community; then
        find /tmp/ltx23-community -type f -name '*.json' -exec cp -f {} "$WORKFLOW_DIR/Community-LTX-2.3/" \;
        python3 - "$WORKFLOW_DIR/Community-LTX-2.3" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
slash = chr(92)
for path in root.glob('*.json'):
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        continue
    def fix(value):
        if isinstance(value, str):
            return value.replace('ltx23' + slash, 'ltx23/').replace('MelBandRoformer' + slash, 'MelBandRoformer/')
        if isinstance(value, list):
            return [fix(x) for x in value]
        if isinstance(value, dict):
            return {k: fix(v) for k, v in value.items()}
        return value
    path.write_text(json.dumps(fix(data), ensure_ascii=False), encoding='utf-8')
PY
        HELPER="$(find /tmp/ltx23-community -type f -name 'two_stage_resolution.py' | head -n1)"
        if [ -n "$HELPER" ]; then
            cp -f "$HELPER" "$PERSIST_ROOT/custom_nodes/two_stage_resolution.py"
            cp -f "$HELPER" "$COMFYUI_DIR/custom_nodes/two_stage_resolution.py"
        fi
        touch "$COMMUNITY_MARKER"
        echo "✅ Community LTX-2.3 workflow pack installed"
    else
        echo "⚠️  Community workflow pack download/extract failed; booting without it"
        report_warn "Community LTX-2.3 workflow pack download failed"
    fi
fi

if [ -f "$PERSIST_ROOT/custom_nodes/two_stage_resolution.py" ]; then
    cp -f "$PERSIST_ROOT/custom_nodes/two_stage_resolution.py" "$COMFYUI_DIR/custom_nodes/two_stage_resolution.py"
fi

mkdir -p "$PERSIST_ROOT/models/checkpoints/ltx23" "$PERSIST_ROOT/models/loras/ltx23" "$PERSIST_ROOT/models/loras/ltx2"
if [ -f "$PERSIST_ROOT/models/checkpoints/ltx-2.3-22b-dev-fp8.safetensors" ]; then
    ln -sfn ../ltx-2.3-22b-dev-fp8.safetensors "$PERSIST_ROOT/models/checkpoints/ltx23/ltx-2.3-22b-dev-fp8.safetensors"
fi
for name in Best_FaceID_v1.0_LoRA.safetensors Best_FaceID_CharacterSheet_v1.0_LoRA.safetensors edit_anything_v1.1_r256.safetensors ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors; do
    if [ -f "$PERSIST_ROOT/models/loras/ltx23/$name" ]; then
        ln -sfn "ltx23/$name" "$PERSIST_ROOT/models/loras/$name"
    fi
done
R105="ltx-2.3-22b-distilled-lora-dynamic_fro09_avg_rank_105_bf16.safetensors"
if [ -f "$PERSIST_ROOT/models/loras/ltx23/$R105" ]; then
    ln -sfn "../ltx23/$R105" "$PERSIST_ROOT/models/loras/ltx2/$R105"
fi
