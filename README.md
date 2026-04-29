```
 █████╗ ██████╗  ██████╗██╗  ██╗     █████╗ ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██╔══██╗██║
███████║██████╔╝██║     ███████║    ███████║██║
██╔══██║██╔══██╗██║     ██╔══██║    ██╔══██║██║
██║  ██║██║  ██║╚██████╗██║  ██║    ██║  ██║██║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝
```

**The first Linux distro you install by talking to it.**

> Hold `Caps Lock`. Say what you want. Watch it happen.

---

## What is ArchAI?

ArchAI is an Arch-based Linux distribution with AI baked into its core — not as an app, not as a plugin, but as a first-class system layer that manages your OS through voice or text commands.

No command line mastery required. No copy-pasting from Stack Overflow. No reading through pages of documentation after a broken update.

You just talk to it.

---

## Features

### Hold Caps Lock. Talk. Done.
Caps Lock is your push-to-talk key. Press and hold — the LED lights up, you're live. Release — the AI responds and executes. Works in a TTY, under X11, under Wayland, in a VM, anywhere. Implemented at the `evdev` level, below any display server.

### AI layer that actually does things
The AI daemon connects to your preferred provider and has scoped `sudo` access to manage:
- Package installation (`pacman`, AUR)
- System services (`systemctl`)
- Web servers (`nginx`, `apache`, `certbot`)
- Network configuration
- File management in system paths

### Always-on local fallback
TinyLlama 1.1B runs locally, always, with no internet required. If your cloud API fails, your token runs out, or you're offline — the local model takes over silently. You never lose control of your system.

### Guided installer with install profiles
Boot the ISO and the AI greets you immediately — no API key required, TinyLlama handles setup. Choose your profile:

| Profile | What you get |
|---|---|
| 🎮 **Gaming rig** | KDE + Steam + Proton + GameMode — ditch Windows for good |
| 🖥️ **Home server** | nginx + Docker + SSL + hardened SSH — own your data |
| 🧰 **Hobby machine** | GNOME + dev tools + media — a bit of everything |
| 🔒 **Pentesting lab** | XFCE + Metasploit + Wireshark + Tor — built like a pro |
| 💻 **Dev workstation** | KDE + VS Code + Docker + full language stack |

### Live execution log
A split tmux interface shows what the AI is executing in real time — no black box, no guessing. Works in pure TTY, no desktop required.

### Multi-provider AI support
| Provider | Notes |
|---|---|
| **Claude (Anthropic)** | Recommended — best reasoning |
| **OpenAI** | GPT-4o and variants |
| **Ollama** | Local models, no internet |
| **LM Studio** | Local via LM Studio server |
| **Custom endpoint** | Any OpenAI-compatible API |
| **TinyLlama 1.1B** | Always-on fallback, baked in |

---

## Build it yourself

### Prerequisites
```bash
sudo pacman -S archiso
```

### 1. Download dependencies (once)
```bash
bash scripts/fetch-deps.sh
```
This downloads TinyLlama (~640MB) and pip wheels. Run once, never again.

### 2. Build the ISO
```bash
bash scripts/rebuild.sh
```
Subsequent builds are fast — packages, the model, and pip wheels are all cached locally.

### 3. Test in a VM
```bash
qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \
  -cdrom build/archai-*.iso \
  -boot d -vga virtio -display gtk
```

---

## First boot experience

```
[ Boot ISO ]

  ArchAI greets you immediately via TinyLlama (no API key needed yet)

  "What are you building? Choose a profile or just describe it."

  > gaming rig

  "Great. I can see /dev/sda (500GB). Use the whole disk?"

  > yes

  [ installation runs — live log visible in bottom pane ]

  "Done. Remove the USB and reboot. Your AI is waiting."

[ First boot of installed system ]

  "I'm running on a local model right now.
   Want to connect Claude or another AI for more power?
   Hold Caps Lock to answer."
```

---

## Architecture

```
┌─────────────────────────────────────┐
│         User (voice or text)        │
└──────────────┬──────────────────────┘
               │  Caps Lock (evdev, kernel level)
               │  or archspeech-cli "command"
               ▼
┌─────────────────────────────────────┐
│         archspeech-daemon           │
│  ┌─────────────┐  ┌──────────────┐  │
│  │ Cloud AI    │  │ TinyLlama    │  │
│  │ (Claude /   │→ │ 1.1B local   │  │
│  │  OpenAI /   │  │ (fallback)   │  │
│  │  Ollama)    │  └──────────────┘  │
│  └─────────────┘                    │
└──────────────┬──────────────────────┘
               │  tool calls
               ▼
┌─────────────────────────────────────┐
│    System tools (scoped sudo)       │
│  pacman · systemctl · nginx         │
│  certbot · nmcli · chown            │
└─────────────────────────────────────┘
```

---

## Project structure

```
archspeech/
├── archiso/
│   ├── profiledef.sh              # distro identity
│   ├── packages.x86_64            # package list
│   ├── pacman.conf                # build pacman config
│   ├── airootfs/
│   │   ├── etc/
│   │   │   ├── archspeech/        # AI config
│   │   │   ├── keyd/              # Caps Lock remapping
│   │   │   ├── sudoers.d/         # scoped AI permissions
│   │   │   └── systemd/system/    # daemon unit files
│   │   └── usr/local/
│   │       ├── bin/               # archspeech-* executables
│   │       └── lib/archspeech/
│   │           └── installer/     # install profiles
│   ├── efiboot/                   # UEFI boot entries
│   └── syslinux/                  # BIOS boot entries
└── scripts/
    ├── fetch-deps.sh              # one-time dependency download
    └── rebuild.sh                 # fast rebuild (uses cache)
```

---

## Roadmap

- [ ] Desktop status widget (post-install, shows AI activity)
- [ ] Offline voice model (Whisper + Piper TTS, no espeak)
- [ ] Graphical installer option
- [ ] AUR helper integration
- [ ] Automatic update management via voice

---

## Contributing

Pull requests welcome. If you build a new install profile, fix a boot issue, or improve the AI prompting — open a PR.

---

## License

MIT
