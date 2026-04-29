# ArchSpeech — Project Kickoff Notes

## The Vision
A custom Arch-based Linux distro with AI + voice control baked into the core.
Not a plugin — a first-class system layer that manages the OS through natural
voice/text commands: packages, configs, services, VHosts, SSL, logs, and more.

---

## Three Core Modules
1. **Arch base system** — built and packaged via `archiso`
2. **AI API layer** — cloud (Claude/Anthropic) first, local (Ollama) in v2
3. **Voice command module** — Whisper.cpp (STT) + Piper (TTS)

---

## Key Decisions Made
- **No bare metal needed to start.** Build and test entirely on Manjaro using
  `archiso`, validate in a VM (QEMU/VirtualBox), then move to hardware.
- **Phase 1 uses cloud API** (lean ISO ~1.5GB, needs internet). Offline/local
  model support comes in v2.
- **AI daemon starts on first boot** via systemd unit in `airootfs/etc/systemd/system/`.
- The same ISO built with `archiso` is both the test artifact and the
  distributable — no separate production build step.

---

## AI Layer Permissions Model (decided)
The AI daemon runs as a dedicated system user (`archspeech`) with scoped
`sudoers.d` rules granting `NOPASSWD` access by category:
- Package management (`pacman`, `yay`)
- Service control (`systemctl`)
- Web server management (`apachectl`, `nginx`, `certbot`)
- File ownership in system paths (`/etc`, `/var/www`, `/srv`)

This gives the seamless, no-friction experience without blanket root access.
Users can audit exactly what ArchSpeech is allowed to touch — a trust feature,
not a limitation.

---

## ISO Size Reference
| Config                         | Size    |
|--------------------------------|---------|
| Base Arch only                 | ~800MB  |
| + Cloud API layer              | ~1.5GB  |
| + Local small model (Ollama 3B)| ~5-6GB  |
| + Local full model (7B+)       | ~10GB+  |

---

## Next Steps (resume here on home network)

### Step 1 — Install archiso
```bash
sudo pacman -S archiso
```

### Step 2 — Scaffold the project structure
Claude will generate all files for this layout:
```
archspeech/
├── archiso/
│   ├── profiledef.sh
│   ├── packages.x86_64
│   ├── pacman.conf
│   ├── airootfs/
│   │   ├── etc/
│   │   │   ├── hostname
│   │   │   ├── os-release
│   │   │   ├── sudoers.d/archspeech     ← scoped AI permissions
│   │   │   └── systemd/system/          ← AI daemon unit files
│   │   └── root/
│   │       └── customize_airootfs.sh
│   └── efiboot/ + syslinux/
```

### Step 3 — Build and test the base ISO in a VM
### Step 4 — Add the AI API daemon layer + sudoers config
### Step 5 — Add the voice module (Whisper.cpp + Piper)

---

## Resume Prompt
Tell Claude: *"I'm back on my home network, let's continue building ArchSpeech.
Please read archstart.md and pick up at Step 1."*
