# iUmrah Business / Kepler Studio — iOS patch v2 (engine v0.2)

**Input:** `iumrah-beta-update-20261010-kepler-business-studio-v1.zip` uploaded by the user. All original app-shell/navigation files and `project.yml` are preserved byte-for-byte. Only the Kepler Business studio view and `Resources/KeplerStudio/` are updated.

## What's new

- **Latest available Kepler Studio engine v0.2**, based on the eight archives analyzed in the conversation (not an invented future version).
- Source ZIP `Resources/KeplerStudio/kepler-studio-v0.2-engine.zip`: 0.2 Python/FFmpeg code, audited MIT reference skills, license notices, checks and docs. Original **private user cards/photographs/third-party image files intentionally excluded** from distributable ZIP, while asset registry retains names and hashes for private provisioning.
- Bundled core `SKILL.md`, engine instructions, four actual motion presets (fade, rise_fade, slide_up_soft, slide_right_soft), nine catalog entries (Kepler Studio core + 8 upstream sources).
- Shareable ZIPs for core + 5 MIT-licensed reference skills. Three external integrations (Remotion Official, Motion AI Kit, WhisperX) link to real GitHub repositories; no in-app installation or unsupported runtime claim.
- Per-skill detail offers verified upstream GitHub link, shareable ZIP when distributed locally, and copy of the actual supplied `SKILL.md` when present.
- Separate buttons `Sync with ChatGPT` and `Sync with Claude` copy the current v0.2 instructions and open respective websites; **not OAuth/automated skill installation**.
- Main-source GitHub URL and build URL deliberately null until the repo owner supplies verified URLs; the UI displays an explicit unconfigured state instead of fabricating links.
- View retains native SwiftUI/Glass only on interactive surfaces, premium static cards, and a genuinely animated neutral motion preview. It never recreates customer-supplied visual assets.

## Critical boundaries

This UI is a catalog/export surface. **No runnable Python/FFmpeg/WhisperX/Remotion engine runs on the iPhone** and no customer/booking administration is granted. Agent references are not automatically installed plugins. For actual rendered videos, use a configured server/self-hosted runner and a reviewed plan.

The engine archive is a *portable source snapshot without private visuals*: restoring exact source files under `assets/original/` is necessary for `verify-assets`, unit tests requiring four originals, and example card rendering. Check usage rights before making any real original asset public.

## Apply

Use the project's existing root overlay ZIP workflow (`iumrah-beta-update-*.zip`). This patch has no enclosing directory and uses the original `Resources/KeplerStudio` resource-folder entry already present in `project.yml`. No backend, secret, signing, bundle ID, version, pricing, hotel, booking or flight logic changes.

## Verification performed

- ZIP entries/JSON fields/embedded archives and SHA-256 manifests validated.
- Swift files syntax-parsed (`swiftc -frontend -parse`) and YAML parsed.
- Original app-shell and project manifest compared byte-for-byte to the user's source patch.
- Kepler Studio v0.2 unit tests run in the local Python environment.

**Not verified:** Xcode SDK compilation, simulator UI, TestFlight signing, remote GitHub Actions. Check CI build on user's actual iOS repository after applying.
