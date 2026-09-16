# comfyui-ltx2

RunPod-oriented ComfyUI template for LTX-2.x.

## Zakk test branch

This branch is intentionally kept separate from `main` while the expanded workflow set is tested.

### What boots by default

- LTX-2.3 model/support files used by the community workflow pack.
- LTX-2.5 support stack and stock INT8 distilled transformer (`download_ltx25=true` by default).
- Official LTX-2.5 two-stage T2V/I2V workflow copied from the installed `ComfyUI-LTXVideo` package.
- Stefan Falkok/RuneXX LTX-2.3 workflow exploration pack installed into `Community-LTX-2.3` on first boot.
- The pack's `two_stage_resolution.py` helper installed automatically.
- Custom node packs referenced by the workflows: LTXVideo, KJNodes, rgthree, LoRA Manager, VideoHelperSuite, MelBandRoFormer, Easy-Use, GGUF, ControlNet Aux, Essentials, Crystools, RMBG, image saver, NVIDIA RTX nodes, WhatDreamsCost, and BFSNodes.

### REDGraft

REDGraft is optional and does not control the rest of the LTX-2.5 stack.

Set `download_redgraft=true` and provide `CIVITAI_API_KEY` to download CivitAI model-version `3250230`. Leave it false/unset to use the stock LTX-2.5 transformer or another checkpoint while retaining the 2.5 text encoders, VAEs, prompt enhancer, duration head, and latent upscalers.

### Hugging Face

Set `HF_TOKEN` and make sure the account has accepted the LTX-2.5 gated model terms. The LTX-2.5 support files are downloaded independently of REDGraft.

### Persistence

The community workflow ZIP is fetched only when its persistent install marker is absent. Models and workflows on the network volume are reused on later boots. `LTX23_WORKFLOW_PACK_URL` can override the public pack URL if that host ever changes.

### NVIDIA RTX Video Super Resolution

The community graphs reference `RTXVideoSuperResolution`, so its node pack is installed. NVIDIA's current VFX package has open Linux/driver compatibility reports; if that specific optional upscale stage misbehaves on a RunPod image, bypass the RTX upscale node while leaving the LTX generation stages intact.
