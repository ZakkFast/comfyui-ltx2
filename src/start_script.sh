#!/usr/bin/env bash
# Image entrypoint (baked into the image; changing it needs a new image tag).

TEMPLATE_DIR=/comfyui-ltx2
TEMPLATE_URL=https://github.com/ZakkFast/comfyui-ltx2.git
TEMPLATE_BRANCH=main
RUNTIME_DIR=/comfyui-runtime
RUNTIME_URL=https://github.com/Hearmeman24/comfyui-runtime.git

sync_template() {
    if [ -d "$TEMPLATE_DIR/.git" ]; then
        git -C "$TEMPLATE_DIR" fetch --depth=1 origin "$TEMPLATE_BRANCH" &&
        git -C "$TEMPLATE_DIR" reset --hard "origin/$TEMPLATE_BRANCH"
    else
        rm -rf "$TEMPLATE_DIR" &&
        git clone --depth=1 --branch "$TEMPLATE_BRANCH" "$TEMPLATE_URL" "$TEMPLATE_DIR"
    fi
}

ok=""
for attempt in 1 2 3 4 5; do
    if sync_template; then ok=1; break; fi
    echo "⚠️  template repo sync attempt $attempt failed (network/DNS?). Retrying in $((attempt * 5))s..."
    sleep $((attempt * 5))
done

if [ -z "$ok" ]; then
    if [ -d "$TEMPLATE_DIR/.git" ]; then
        echo "⚠️  GitHub unreachable after retries. Booting with the existing on-disk template copy (may be stale)."
    else
        echo "❌ Could not clone $TEMPLATE_URL after retries and no local copy exists. Aborting." >&2
        exit 1
    fi
fi

RUNTIME_REF="$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['runtime_ref'])" "$TEMPLATE_DIR/pins.json" 2>/dev/null)"
if [ -z "$RUNTIME_REF" ]; then
    echo "⚠️  Could not read runtime_ref from $TEMPLATE_DIR/pins.json. Falling back to the runtime's main branch (UNPINNED)."
    RUNTIME_REF=main
fi

runtime_fresh_clone=""
sync_runtime() {
    if [ ! -d "$RUNTIME_DIR/.git" ]; then
        rm -rf "$RUNTIME_DIR"
        git clone "$RUNTIME_URL" "$RUNTIME_DIR" || return 1
        runtime_fresh_clone=1
    fi
    git -C "$RUNTIME_DIR" fetch origin "$RUNTIME_REF" &&
    git -C "$RUNTIME_DIR" reset --hard FETCH_HEAD
}

ok=""
for attempt in 1 2 3 4 5; do
    if sync_runtime; then ok=1; break; fi
    echo "⚠️  runtime repo sync attempt $attempt failed (network/DNS?). Retrying in $((attempt * 5))s..."
    sleep $((attempt * 5))
done

if [ -z "$ok" ]; then
    if [ -d "$RUNTIME_DIR/.git" ]; then
        if [ -n "$runtime_fresh_clone" ]; then
            echo "⚠️  Cloned the runtime but could not fetch the pinned ref $RUNTIME_REF. Booting the runtime's main HEAD: UNPINNED and NEWER than the pin."
        else
            echo "⚠️  Could not sync the runtime to $RUNTIME_REF. Booting with the existing on-disk runtime copy (may be stale)."
        fi
    else
        echo "❌ Could not clone $RUNTIME_URL after retries and no local copy exists. Aborting." >&2
        exit 1
    fi
fi

# Optional REDGraft LTX-2.5 checkpoint.
# Reuse the runtime's existing CivitAI downloader instead of adding another downloader.
# REDGraft is a diffusion model, while the shared downloader stores CivitAI checkpoints
# under models/checkpoints, so expose it to UNETLoader with a lightweight symlink.
if [ "${download_redgraft:-false}" = "true" ]; then
    echo "🎬 REDGraft enabled; enabling the required LTX-2.5 model set"
    export download_ltx25=true

    REDGRAFT_VERSION_ID=3250230
    case ",${CIVITAI_CHECKPOINTS:-}," in
        *",${REDGRAFT_VERSION_ID},"*) ;;
        *) export CIVITAI_CHECKPOINTS="${CIVITAI_CHECKPOINTS:+${CIVITAI_CHECKPOINTS},}${REDGRAFT_VERSION_ID}" ;;
    esac

    REDGRAFT_NAME="redgraftLTX25Fast2K_ltx25RedgraftNSFW.safetensors"
    mkdir -p /workspace/ComfyUI/models/diffusion_models
    ln -sfn "../checkpoints/${REDGRAFT_NAME}" "/workspace/ComfyUI/models/diffusion_models/${REDGRAFT_NAME}"
fi

exec bash /comfyui-runtime/src/start.sh /comfyui-ltx2
