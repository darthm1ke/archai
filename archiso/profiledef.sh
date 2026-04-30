#!/usr/bin/env bash

iso_name="aios"
iso_label="AIOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="AIos Project"
iso_application="AIos - AI-native Linux powered by Arch"
iso_version="0.2.0"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d/archspeech"]="0:0:440"
  ["/usr/local/bin/archspeech-daemon"]="0:0:755"
  ["/usr/local/bin/archspeech-voice"]="0:0:755"
  ["/usr/local/bin/archspeech-cli"]="0:0:755"
  ["/usr/local/bin/archspeech-setup"]="0:0:755"
  ["/usr/local/bin/archspeech-live"]="0:0:755"
  ["/usr/local/bin/aios-status"]="0:0:755"
  ["/usr/local/bin/aios-model-setup"]="0:0:755"
  ["/usr/local/bin/archspeech-ptt"]="0:0:755"
  ["/usr/local/bin/archspeech-ui"]="0:0:755"
  ["/usr/local/bin/archspeech-installer"]="0:0:755"
  ["/usr/local/lib/archspeech/installer/log.sh"]="0:0:755"
  ["/usr/local/lib/archspeech/installer/common.sh"]="0:0:755"
  ["/usr/local/lib/archspeech/installer/profiles/gaming.sh"]="0:0:755"
  ["/usr/local/lib/archspeech/installer/profiles/server.sh"]="0:0:755"
  ["/usr/local/lib/archspeech/installer/profiles/hobby.sh"]="0:0:755"
  ["/usr/local/lib/archspeech/installer/profiles/pentest.sh"]="0:0:755"
  ["/usr/local/lib/archspeech/installer/profiles/developer.sh"]="0:0:755"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/root/.automated_script.sh"]="0:0:755"
)
