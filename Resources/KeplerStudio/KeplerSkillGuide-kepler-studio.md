---
name: kepler-studio
summary: Evidence-based editing that animates registered immutable user assets; separate AI planning, human review and rendering.
---
# Kepler Studio — Core AI Skill v0.2

Read `AGENTS.md` first. This file outranks all reference Skills under `upstream/`.

## Source-of-truth hierarchy

1. User's actual media, registered original assets, explicit instructions, and user-approved output requirements.
2. Exact transcript segments and frame samples; do not invent speech or describe unseen footage.
3. Engine contract (`assets/registry.json`, approved `assets/motion_presets.json`, plan validator).
4. Upstream Skills are educational references, **never permission to redraw assets or hallucinate visual scenes**.

## Mandatory workflow

1. `inspect` actual footage; write source media dimensions, audio status, frame samples.
2. `transcribe` via real ASR when installed, flag word alignments as unverified; correct Uzbek words before publishing.
3. For each relevant phrase, propose a registered asset with exact transcript evidence and a time range. No speech evidence = no auto-selected card.
4. Recommend only named registered preset (`fade`, `rise_fade`, `slide_up_soft`, `slide_right_soft`); NO invented presets or replacement graphics.
5. Human reviews plan and explicitly runs `approve-plan`; preserve the draft unchanged.
6. Render approved plan, preserving original source pixels and card aspect ratio.
7. Run audit, inspect multiple output frames (including motion midpoints), check mouth/face safety and genuine A/V synchrony. If uncertain, do not claim completed professional quality.

## Upstream skill selection (reference, not execution)

- `upstream/video-use/SKILL.md` for source-first editing process, shot/cut guidance and engineering QA.
- `upstream/videoediting/skill/videoediting/SKILL.md` for FFmpeg, speech cuts, EQ and subtitles.
- `upstream/motion-design/SKILL.md` and its `skills/entrance-patterns/`, `skills/easing/`, `skills/sequencing/` for motion vocabulary; **do not copy Material defaults over Apple look**.
- `upstream/remotion-motion-graphics/skills/motion-graphics/SKILL.md` for compositing concepts; only animate *given* transparent PNG cards, never recreate them.
- `upstream/watch/skills/watch/SKILL.md` for frame inspection ideas (may require an external API/tool).
- `integrations/external/` for official Remotion Skills, Motion AI Kit and WhisperX instructions; not bundled or activated by default.

## Explicitly forbidden

- Writing random marketing subtitles, made-up spoken quotations, extra UI, logos, fake partners or ratings.
- Redrawing, reformatting or recreating any original card image, even if it looks cleaner after redraw.
- Non-uniform stretch of source video; software scaling does not invent source detail.
- Automatic plan approval by an AI agent, hiding review flags, or publishing `--preview` as an approved output.

## Quick commands

```bash
python -m kepler_studio verify-assets
python -m kepler_studio inspect --video source.mp4 --output local/inspect.json --stills local/stills
python -m kepler_studio transcribe --video source.mp4 --output local/transcript.json --language uz --engine faster-whisper
python -m kepler_studio plan --transcript local/transcript.json --output local/draft.json --mode rules
python -m kepler_studio approve-plan --plan local/draft.json --output local/approved.json --confirm-reviewed
python -m kepler_studio audit --video source.mp4 --plan local/approved.json --output local/audit.json
python -m kepler_studio render --video source.mp4 --plan local/approved.json --output local/render.mp4
```
