# Vivado-on-Apple-Silicon Fork — Phase 0 Audit & Migration Plan
**This Plan created for making this project m4 and 2026 fitted**
**Status:** Audit only. No implementation code has been written yet. This is the
consolidated Phase 0 deliverable required before any destructive change to the fork.

**Research method / limitation to disclose up front:** This audit was produced by
fetching the public GitHub pages (READMEs, file listings, issues/discussions) for
`ichi4096/vivado-on-silicon-mac`, `minorin22/vivado-on-silicon-mac`, and
`daitomanabe/vivado-mac-cli`. GitHub's `robots.txt` blocks automated crawling of
`/tree/` and `/blob/` pages, and this environment has no outbound network access for
`git clone`, so **individual shell scripts inside `ichi4096` and `minorin22` were not
read line-by-line**. Items below marked `[confirmed]` come directly from repository
documentation; items marked `[inferred]` are reasonable expectations that must be
verified against actual script source the moment the repo is cloned locally — this is
made the literal first implementation task (§13).

---

## 1. Current architecture map

**GUI path** `[confirmed from ichi4096's docs, except desktop environment]`:

```
macOS (Apple Silicon)
  └─ Docker Desktop (Apple Chip build)
       └─ Apple Virtualization Framework + Rosetta 2
            └─ linux/amd64 Ubuntu container (Dockerfile pins `--platform=linux/amd64`)
                 └─ Desktop environment + VNC server   [inferred: LXDE + TigerVNC —
                                                         exact DE not confirmed from
                                                         docs alone, verify from Dockerfile]
                      └─ macOS Screen Sharing.app (client)
                           └─ Vivado GUI
```

**JTAG/USB path** `[confirmed]`:

```
macOS host → xvcd (bundled fork of tmbinc/xvcd, LGPL-2.1, FT2232C-only)
           → TCP (Xilinx Virtual Cable protocol)
           → Vivado hw_server inside the container
```

USB isn't passed through the VM at all — Apple's Virtualization Framework has no USB
passthrough, which is *why* XVC exists here, not an optional extra.

**File map** (from ichi4096's own "Files overview"):

| File | Purpose | Confidence |
|---|---|---|
| `header.sh` | shared shell functions | confirmed |
| `setup.sh` | one-time setup entry point | confirmed |
| `configure_docker.sh` | "automatically set necessary Docker settings" | exists; **mechanism unconfirmed** — plausibly patches `~/Library/Group Containers/group.com.docker/settings.json` directly, but must be re-read from source |
| `gen_image.sh` | builds the Docker image | confirmed |
| `hashes.sh` | hash → Vivado-version lookup table | confirmed to exist; MD5 vs other hash unconfirmed from docs, but plausible given the coding rule against MD5 |
| `linux_start.sh` | in-container startup | confirmed |
| `de_start.sh` | runs once desktop env is up | confirmed |
| `cleanup.sh` | removes Vivado + dotfiles | confirmed |
| `xvcd/` | XVC daemon source + binary | confirmed |
| `install_bin`, `vnc_resolution`, `vncpasswd` | plain-text config files | confirmed |

**Correction to the original brief:** the brief mentions `Dockerfile`,
`install_vivado.sh`, and `install_configs/`. The real upstream README names no such
standalone `install_vivado.sh`/`install_configs/` — that logic most likely lives inside
`gen_image.sh`/`setup.sh`/the Dockerfile itself. Treat the brief's file list as an
approximate mental model to reconcile against the real tree, not a verified inventory.

**Persistence model — the real structural problem** `[confirmed]`: the entire cloned
repo folder is bind-mounted as `/home/user`, and Vivado is installed *inside that same
folder* (docs explicitly say third-party installers must go into `/home/user/Xilinx`,
"because any data outside of `/home/user` does not persist"). So today:

- The current Vivado path convention is **`~/Xilinx/...` under the bind mount**, not
  `/opt/Xilinx/...`.
- Deleting/moving/`git clean`-ing the repo destroys the entire install.

This confirms brief problem #9 directly and adds a migration detail the brief didn't
anticipate (see §10).

**Version detection today** `[inferred, high confidence]`: `installer binary → hash →
hashes.sh lookup → static version ID (e.g. 202410) → static per-version config`. Closed
set — adding 2026.1 the old way would mean just adding a row, which the brief correctly
forbids doing again.

---

## 2. Differences between the three repos

| Axis | ichi4096 (upstream) | minorin22 | daitomanabe/vivado-mac-cli |
|---|---|---|---|
| License | CC0-1.0 | fork, license file unverified | MIT |
| Newest Vivado | 2024.1 | **2025.1** | **2026.1** |
| Virtualization | Docker + AVF + Rosetta | same as upstream | **No Docker at all** — Swift CLI drives `Virtualization.framework` directly: ARM64 Ubuntu 24.04 guest + Rosetta 2 via `binfmt_misc`, running amd64 Vivado ELF binaries in an otherwise-native ARM64 userland |
| GUI | Full GUI, TigerVNC + Screen Sharing | Full GUI; recommends **TigerVNC Viewer** instead of Screen Sharing, for HiDPI | **Headless only, by design** — explicitly points GUI users back to ichi4096 |
| Board/library support | none | **Digilent `vivado-boards`/`vivado-library` as git submodules** — real, confirmed | N/A |
| Version detection | static hash table | same mechanism, just more hash rows | no hash gate — uses whatever installer AMD ships |
| Licensing | pre-2026 behavior | same | **Directly solves 2026.1's mandatory node-locked license**: pins the VM's MAC permanently; documents that AMD limits re-hosting to ~once/year |
| 2026.1 Rosetta workarounds | N/A | N/A | **Full documented catalog** (below) — found in an ARM64-native context, not amd64-Docker |
| JTAG | xvcd, FT2232C only | inherits | none — recommends openFPGALoader or separate XVC |
| Persistence | repo-folder bind mount doubles as install dir | unconfirmed if changed | clean split: VM disk = `/opt/Xilinx`, only `/work` shared via virtiofs |

**Reuse from minorin22:** the Digilent submodule pattern; the "use TigerVNC Viewer, not
Screen Sharing" nudge (this becomes the Phase-3 MVP, see §9).

**Do NOT copy from daitomanabe:** its architecture (no Docker, headless). It's
excellent evidence for licensing/Rosetta behavior, not a blueprint — adopting it would
mean giving up the full-GUI requirement.

### Rosetta workaround catalog — applicability to *our* amd64 Docker container

| Workaround | Root cause (daitomanabe's ARM64 userland) | Relevance to us | Action |
|---|---|---|---|
| `uname`/`arch` shim | base OS genuinely reports `aarch64` | **probably not needed** — our amd64-platform container already reports `x86_64` natively | doctor.sh asserts this, don't pre-emptively shim |
| `JAVA_TOOL_OPTIONS=-Djdk.lang.Process.launchMechanism=FORK` | JVM `vfork` breaks under Rosetta spawning `/bin/sh` | **possibly relevant** — same Rosetta engine underneath | conditionally enable; try without first, capture failure signature |
| `-Djava.net.preferIPv4Stack=true` | AMD's CDN returns AAAA records, VZ NAT is IPv4-only | Docker's NAT is also commonly IPv4-only | safe low-risk default, not proven necessary |
| lscpu/FeatureStore `std::stoi` crash (**new in 2026.1**) | FeatureStore execs `lscpu`, parses fields that read `-` on ARM-flavored `/proc/cpuinfo` | **highest-priority open question** — unknown whether our amd64-via-Rosetta container's `/proc/cpuinfo` has the same gap | **do not port speculatively** — build a smoke test first (§13) |
| missing `libpixman-1.so.0`/`libncurses.so.5` | ARM multiarch package gaps | arch-independent — can also hit real x86_64 Ubuntu if too new | verify once base Ubuntu version is chosen, not Rosetta-specific |
| `realloc()` invalid pointer (libudev) | not reproduced by daitomanabe on 2026.1; kept opt-in | keep same posture | off by default, `LD_PRELOAD` stub available via flag |
| missing x86-64 loader | pure ARM64 userlands don't ship one | **not applicable** — solved for free by staying on full amd64 Ubuntu | no action — argument *for* keeping Docker |

---

## 3. Files that need modification

| File | Why |
|---|---|
| `Dockerfile` | base image pin review, SHA-256 tooling, drop assumptions tied to the old install-into-repo layout |
| `configure_docker.sh` | replace brittle direct Docker Desktop internals edits with detection + a `doctor` check; refuse to silently patch undocumented files |
| `gen_image.sh` | adjust for named-volume persistence instead of whole-repo bind mount |
| `hashes.sh` | split into (a) metadata-driven version detection and (b) independent SHA-256 integrity check — kept read-only for legacy versions during transition |
| `linux_start.sh` / `de_start.sh` | persistent-MAC launch flags, `XILINXD_LICENSE_FILE` wiring, conditional Rosetta/Java workarounds (env-gated), explicit `127.0.0.1` VNC binding |
| `start_container.sh` | stop launching Screen Sharing by default; point at TigerVNC Viewer or the native client; read from named volumes / `~/VivadoProjects` |
| `README.md` | full rewrite once the above lands |

## 4. Files to add

| File | Purpose |
|---|---|
| `scripts/doctor.sh` | validates macOS, arm64 host, Rosetta, Docker install/daemon, Rosetta-capable backend, amd64 execution, container image, Vivado install + version, license, VNC-localhost-only, project mounts, JTAG/XVC status |
| `installer/detect-version.sh` | prefers `xsetup -b ConfigGen`-style metadata over hash lookup; falls back to hash table only for pre-2026 installers |
| `installer/verify-checksum.sh` | SHA-256, separate concern from version detection |
| `config/machine.env` (template only) | `VIVADO_MAC=...` — no real values committed |
| `config/defaults.env` | non-secret defaults (VNC resolution, ports, volume names) |
| Rosetta/Java workaround shims | each conditionally invoked, gated by its own detection test |
| `examples/blinky/` | minimal HDL project for smoke-testing synth→impl→bitstream |
| `macOS/` Swift package skeleton | `Package.swift`, `Sources/Launcher`, `Sources/RFB/{Connection,Framebuffer,Clipboard,Keyboard,Mouse}`, `Sources/UI` |
| `tests/` | ShellCheck config, smoke tests |
| `.github/workflows/` | lint/ShellCheck on PR at minimum; full build/doctor runs need self-hosted Apple Silicon runners — later nice-to-have |

## 5. Files to eventually deprecate/remove

- Whole-repo-as-`/home/user` bind mount → replaced by named volumes + `~/VivadoProjects`, with an explicit (never silent) one-time migration step for existing installs
- `hashes.sh` as the *primary* detection path → superseded once metadata-driven detection covers all supported versions; kept read-only in the meantime
- Apple Screen Sharing as the *default* viewer → stays available manually, just stops being launched by default once TigerVNC Viewer (then the native client) is in place
- Any remaining MD5-only integrity checks

---

## 6. 2026.1-specific compatibility risks

1. **FeatureStore `lscpu`/`std::stoi` crash** — the single highest-priority unknown; must be tested empirically inside our real `linux/amd64` container before deciding to port the shim.
2. **Licensing is now mandatory**, even for BASIC-tier free use. Without a stable machine identity across container recreation, users get forced into a license re-host that AMD reportedly rate-limits to ~once/year. This makes persistent MAC a hard requirement, not a nice-to-have.
3. **Installer/Java Rosetta behavior** (vfork spawning `/bin/sh`, IPv4-only NAT download failures) may or may not reproduce under Docker's Rosetta backend vs. daitomanabe's binfmt-based Rosetta — needs its own test.
4. **Base OS/library drift** — whatever Ubuntu version Phase 1 settles on needs checking against 2026.1's actual runtime expectations; legacy compat libs (`libncurses5`-class) have a history of disappearing from newer Ubuntu regardless of CPU arch.
5. **`xsetup -b ConfigGen` output format in 2026.1 is unknown** until captured from a real installer run — this is a concrete hands-on task, not something finishable from docs alone.

## 7. M4-specific risks

No evidence M4 needs a distinct code path. daitomanabe's project is verified
specifically on an M4 Mac and needed no chip-generation branching — everything is
framed as "Apple Silicon" generically. The only M4-specific action is **testing and
documenting** it in doctor output and release notes, not writing conditional logic
keyed to chip generation. If a genuine M4-only issue surfaces during testing, handle it
as a targeted documented exception then — don't pre-build a generation abstraction
speculatively.

## 8. Licensing implications

- `config/machine.env` holds a stable `VIVADO_MAC`, launched with the container every time — no more disposable `docker run --rm`-style identity churn.
- `XILINXD_LICENSE_FILE` wired to `~/.config/<project-name>/licenses/`, outside the Git tree, never touched by repo updates or `git clean`.
- Support both forms of `XILINXD_LICENSE_FILE`: a local `.lic` path (free node-locked BASIC tier) and a `port@host` floating-license string (paid tiers).
- Never commit real license files, AMD credentials, or auth tokens — ship only a placeholder template.
- Document clearly, *before* any destructive command, that regenerating/destroying the persistent identity forces a license re-host, rate-limited by AMD.

## 9. Clipboard implementation plan

**MVP (Option A):** stop launching Screen Sharing by default; ship instructions (and
ideally a `scripts/attach.sh` wrapper) that launch **TigerVNC Viewer** against the
localhost-bound VNC port instead. TigerVNC's own clipboard bridging already works where
Apple's client doesn't — zero new code, immediate win, and exactly what minorin22
already nudges toward for HiDPI.

**Long-term (Option B):** native Swift RFB client:

```
macOS/
  Package.swift
  Sources/
    Launcher/
    RFB/
      Connection/
      Framebuffer/
      Clipboard/
      Keyboard/
      Mouse/
    UI/
```

MVP feature set: RFB 3.8 handshake/compat, framebuffer rendering, keyboard/mouse input,
bidirectional clipboard (`NSPasteboard` ⇄ RFB `ClientCutText`/`ServerCutText` ⇄ X11
`CLIPBOARD`), Retina/HiDPI scaling, resizable/fullscreen window, robust plain-`127.0.0.1`
handling (no TLS/auth complexity needed). Out of scope for MVP: extended RFB
pseudo-encodings, multi-monitor spanning, remote connections.

**Licensing care:** TigerVNC is GPL-2.0. A from-scratch Swift implementation against
the public RFB 3.8 spec (not ported TigerVNC source) can carry its own license;
attribution to TigerVNC and `tmbinc/xvcd` retained regardless.

**Test matrix:** macOS→Vivado and Vivado→macOS, ASCII, UTF-8, multi-line text, Turkish
keyboard characters, Cmd/Ctrl and Option/Alt mapping sanity.

## 10. Persistent storage plan

```
Docker named volume  vivado-install   → /opt/Xilinx
Docker named volume  vivado-home      → /home/user
macOS bind mount     ~/VivadoProjects → /workspace
Persistent config    ~/.config/<project-name>/
Persistent license   ~/.config/<project-name>/licenses/
```

Migration wrinkle not in the original brief: the *current* documented convention is
`~/Xilinx/...` under the old bind mount, not `/opt/Xilinx/...`. The path/version
detector must check both during the transition, and `setup.sh` needs an explicit opt-in
migration step (copy existing install into the new volume, or reinstall cleanly) —
never silent.

Path/version detection helper supports, as one reusable function, both known layouts
(`/opt/Xilinx/Vivado/<VERSION>/` and `/opt/Xilinx/<VERSION>/Vivado/`) plus the legacy
`~/Xilinx/...` path for back-compat — explicit ordered search, no fragile globbing,
clear failure messages surfaced through `doctor.sh`.

Deleting the Git repo must never delete the named volumes, `~/VivadoProjects`, or
`~/.config/<project-name>`; `setup.sh`/`cleanup.sh` should make this guarantee explicit
and require confirmation before touching anything under those paths.

## 11. Migration strategy

- No big-bang rewrite. Phase 1 modernizes the existing Docker/VNC stack in place while keeping it usable for currently-supported older Vivado versions.
- Version-detection redesign is additive; legacy hash table stays read-only as fallback until fully retired.
- Data migration: explicit one-time step to move an existing bind-mount install into named volumes, or start fresh in the new layout — never silent.
- Licensing migration is purely additive (didn't exist for older versions) — but the MAC-pinning requirement must be very visible before first 2026.1 install.
- Viewer migration: Screen Sharing keeps working manually; TigerVNC Viewer becomes the documented default; the native client arrives later as a strict upgrade, not a breaking change to the RFB server side.

## 12. Proposed milestone structure

1. **M0 — Audit** (this document) — done, pending review.
2. **M1 — Modernized stack**, still Docker/LXDE/TigerVNC/Screen-Sharing-optional: `doctor.sh`, Rosetta/Docker detection, persistent volumes, path/version helper, ported minorin22 board submodules, logging/error-handling cleanup.
3. **M2 — Vivado 2026.1.x support**: metadata-driven detection, SHA-256 checks, persistent MAC + `XILINXD_LICENSE_FILE`, conditional Rosetta/Java workarounds gated by real tests, `vivado -version` + minimal batch HDL smoke test passing.
4. **M3 — Clipboard**: TigerVNC Viewer as documented default (fast win); native Swift RFB client MVP with bidirectional clipboard once feature-complete.
5. **M4 — FPGA flow validation**: `examples/blinky/` end-to-end through bitstream generation; hardware programming test via XVC/hw_server if hardware available.
6. **M5 — Hardening**: ShellCheck, CI, deterministic builds, upgrade/uninstall paths, backup/migration docs, README rewrite.

## 13. First implementation task

Before any script logic gets written:

1. **Clone `ichi4096` and diff against `minorin22` locally**, read `configure_docker.sh`, `hashes.sh`, `linux_start.sh`, `de_start.sh` line-by-line to confirm or correct every unconfirmed item above (Docker settings-patching mechanism, hash algorithm, VNC bind address, exact desktop environment).
2. **On a real M4 Mac with Vivado 2026.1**, run the smallest possible reproduction of the `lscpu`/FeatureStore `std::stoi` crash inside the unmodified `linux/amd64` container — this single data point determines how much of the Phase-2 workaround work is even needed.
3. **Only then** write `scripts/doctor.sh` — the lowest-risk, highest-value new file — since it needs to check *actual* detection points, not assumed ones.

This keeps Phase 0 honest: the analysis above is the best available from public
documentation, but the two verification steps in this section are the true "first
implementation task," and should happen before any script is edited.
