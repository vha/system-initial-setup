<!-- Copilot / AI agent instructions for the `fedora-utils` repo -->

## Purpose

This repo is a collection of KDE Plasma post-install utilities and interactive helpers (shell scripts). Originally focused on Fedora, it now supports both Fedora and Kubuntu. The guidance below is focused on being immediately productive editing and extending these scripts while preserving project conventions.

## Big picture

- **Supported distros**: Fedora (dnf), Ubuntu/Kubuntu (apt)
- **Repo layout**: Top-level scripts: `01. post-install.sh`, `02. install-common-apps.sh`, `03. kde-firsttime-config.sh`, an interactive helper `pkg`, and `bootstrap.sh` (master runner).
- **Responsibility**: User-facing shell scripts that run on fresh KDE Plasma desktop installs. Changes must prioritize idempotence, safe defaults, and **cross-distro compatibility**.
- **External systems**: Scripts interact with `dnf`/`apt`, `flatpak`, `systemctl`, `snapper`/`timeshift`, `qdbus`, and `kwriteconfig6` (KDE CLI). `pkg` requires `fzf`.

## Cross-distro architecture

Each script detects the OS at runtime using `/etc/os-release`:

- **Fedora** (`ID=fedora`): uses `dnf` for package management; includes RPM Fusion repos, snapper for backups, akmod-nvidia for drivers.
- **Ubuntu/Kubuntu** (`ID=ubuntu`): uses `apt` for package management; uses universe/multiverse repos, timeshift for backups, nvidia-driver package.

Helper functions are distro-agnostic:

- `pkg_cmd()`: Wraps `dnf` or `apt` based on detected OS.
- `pkg_install()`: Installs packages via the appropriate manager.
- `pkg_group_install()`: Installs groups (dnf-only); no-op on apt.
- Legacy aliases (`dnf_safe()`, `dnf_cmd()`) still work for backward compatibility but now call the distro-agnostic wrappers.

## Key conventions & patterns (do not break)

- Scripts prefer resilience over strict failure: `set +e` is used and many commands end with `|| true` to avoid aborting a long setup.
- **Distro detection must happen early**: Each script checks `/etc/os-release` at the start; don't hardcode `dnf` or `apt` anywhere—always use helpers.
- Small helper functions are reused: `log()`, `pkg_install()`, `pkg_cmd()`, and `flatpak_safe()` patterns appear. Reuse these helpers when adding similar ops.
- Prefer Flatpak for GUI apps. See `02. install-common-apps.sh` for examples using `flatpak install -y flathub <ID>`.
- **Use conditional blocks for distro-specific operations**: When a package has different names (`openssh-clients` vs `openssh-client`) or a feature is distro-only (e.g., snapper is Fedora, timeshift is Ubuntu), wrap the logic in `if [ "$PKG_MGR" = "dnf" ]; then ... else ... fi`.
- KDE config is done via `kwriteconfig6` and applied with `qdbus` in `03. kde-firsttime-config.sh`; edits must run in an active KDE session to take effect. This is distro-agnostic.
- Hardware detection uses system queries: `lspci | grep -qi nvidia` (same on both distros).

## How to run and test locally

- Syntax-check shell scripts: `bash -n "01. post-install.sh"` and run `shellcheck` where available.
- Run scripts interactively as your user: `bash "01. post-install.sh"` (scripts use `sudo` internally where needed).
- For KDE settings, test `kwriteconfig6` lines in a live KDE session and reload with: `qdbus org.kde.KWin /KWin reconfigure` and `qdbus org.kde.plasmashell /PlasmaShell refreshCurrentShell`.
- `pkg` requires `fzf`. Test by running `./pkg` and trying search/install flows; it will prompt before installing.

## Editing guidelines for AI agents

- **Preserve distro-agnostic principle**: Use `pkg_install()`, `pkg_cmd()` or similar. If a package name differs, add conditional logic. Never assume `dnf` or hardcode `apt`.
- Preserve `set +e` and `|| true` semantics unless the change explicitly tightens failure handling; call out any risk when changing to `set -e`.
- Keep operations idempotent: adding package installs should be additive and safe to re-run (use `pkg_install -y` / `pkg_cmd install -y` as the project does).
- When adding new apps, follow the pattern in `02. install-common-apps.sh`: use `flatpak_safe <app-id>` for GUI and package helpers for CLI/system tools.
- **For distro-specific packages**: e.g., `phonon-qt6-backend-vlc` (Fedora) vs `phonon-backend-vlc` (Ubuntu), wrap in `if [ "$PKG_MGR" = "dnf" ]` blocks.
- For system-level changes (drivers, services), mirror the existing flow: detect hardware first (e.g., `lspci`), then use `pkg_install()` and conditionally wrap distro-specific setup.
- For KDE settings, prefer existing `kwriteconfig6` usage. If adding new keys, find the target file (e.g., `kwinrc`, `plasmarc`, `kdeglobals`) and use the same `kwriteconfig6 --file <file> --group <group> --key <key> <value>` pattern (distro-agnostic).

## Examples from repository

- Add a Flatpak GUI app: follow `02. install-common-apps.sh` and add `flatpak_safe org.example.App`.
- Add a CLI tool (single distro): use `pkg_cmd install -y <pkg>` for distro-agnostic or `if [ "$PKG_MGR" = "dnf" ]; then pkg_install <fedora-pkg>; else pkg_install <ubuntu-pkg>; fi` for conditional.
- Respect Fedora versioning when needed: use `FEDORA_VER=$(rpm -E %fedora)` in a Fedora-only block.
- Add Ubuntu repos: use `sudo_run add-apt-repository -y <ppa>` in Ubuntu-only blocks.

## Testing & validation

- Run `bash -n <script>` for syntax checks.
- Use `shellcheck` for linting changes; note intentional patterns (ignore SC2164/SC2154 warnings where the script intentionally continues despite failures).
- For KDE changes, test in an active KDE session; many changes require logout/login or `qdbus` reloads.

## Integration notes

- The scripts assume `sudo` is available and that the user can elevate privileges.
- Flatpak remote `flathub` is added in `01.`; do not duplicate remote-adds without `--if-not-exists`.
- `pkg` provides a combined DNF/Flatpak interactive UI — changes to package lists should keep the two-backend merge and `fzf` preview behavior.

## When in doubt

- Ask for clarification about intended strictness (should the script abort on failure?). If requested, narrow changes to a single script and provide a safe rollback path.
- Preserve CLI UX: scripts print summary notes and recommended next steps; maintain these user-facing messages.

## Feedback

If anything is unclear or you want a stricter failure model, tell me which script(s) to target and I'll propose a focused patch.
