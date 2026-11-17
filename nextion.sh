#!/usr/bin/env bash
# nextion-editor-linux — Nextion Editor (LTS) için Linux başlatıcısı
# https://github.com/SerhanEnsar/nextion-editor-linux
#
# Nextion Editor, Windows'a özel bir .NET Framework 2.0 uygulamasıdır. Bu betik onu
# Wine + Microsoft .NET 3.5 SP1 ile ayrı bir Wine ortamında çalıştırır.
set -euo pipefail

VERSION="1.0.0"
NEXTION_URL="https://nextion.tech/download/nextion-setup-vLTS.zip"
NEXTION_EXE_SHA256="6f5bb0c374afcd6438499a2d41aa1d9f32de206e3fb4ecec41607786e45ff64f"

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine-nextion}"
export WINEDEBUG="${WINEDEBUG:--all}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nextion-editor"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mUYARI:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mHATA:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
nextion-editor-linux $VERSION

Kullanım: $(basename "$0") [seçenek]

  (seçeneksiz)   Gerekirse kurulumu yapar ve Nextion Editor'ü başlatır
  --install      Komutu ~/.local/bin/nextion-editor olarak kurar, uygulama menüsüne ekler
  --uninstall    Menü kaydını ve komutu kaldırır (Wine ortamı ve projeler korunur)
  --reset        Wine ortamını ($WINEPREFIX) silip baştan kurar
  --help         Bu yardımı gösterir

Ortam değişkenleri:
  NEXTION_DIR    NextionEditor.exe'nin bulunduğu klasör (varsayılan: otomatik)
  NEXTION_DPI    Arayüz ölçeği: 96 (%100), 144 (%150), 192 (%200). Varsayılan: otomatik
  WINEPREFIX     Wine ortamı (varsayılan: ~/.wine-nextion)
EOF
}

# ---------------------------------------------------------------- bağımlılıklar
check_deps() {
  local missing=()
  for c in wine winetricks curl unzip cabextract; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    die "Eksik paketler: ${missing[*]}
       Kurmak için:  sudo apt install wine winetricks curl unzip cabextract"
  fi

  # Ubuntu/Debian paketlerinde wineserver PATH'te değildir; winetricks de buna ihtiyaç duyar
  if [ -z "${WINESERVER:-}" ]; then
    local c
    for c in "$(command -v wineserver 2>/dev/null || true)" \
             /usr/lib/x86_64-linux-gnu/wine/wineserver /usr/lib/wine/wineserver \
             /opt/wine-stable/bin/wineserver /opt/wine-staging/bin/wineserver; do
      if [ -n "$c" ] && [ -x "$c" ]; then export WINESERVER="$c"; break; fi
    done
  fi
  [ -n "${WINESERVER:-}" ] || die "wineserver bulunamadı. WINESERVER=/yol/wineserver ile belirtin."
}

wait_wine() { "$WINESERVER" -w; }

# ---------------------------------------------------------------- editör dosyaları
find_app_dir() {
  local d
  for d in "${NEXTION_DIR:-}" "$SCRIPT_DIR" "$PWD" "$DATA_DIR"; do
    if [ -n "$d" ] && [ -f "$d/NextionEditor.exe" ]; then
      APP_DIR="$(cd "$d" && pwd)"; return 0
    fi
  done
  [ -z "${NEXTION_DIR:-}" ] || die "NEXTION_DIR=$NEXTION_DIR içinde NextionEditor.exe yok."
  download_editor
  APP_DIR="$DATA_DIR"
}

download_editor() {
  info "Nextion Editor LTS resmi siteden indiriliyor: $NEXTION_URL"
  local tmp; tmp="$(mktemp -d)"
  curl -fL --progress-bar -o "$tmp/nextion.zip" "$NEXTION_URL" || die "İndirme başarısız."
  mkdir -p "$tmp/x"
  unzip -q "$tmp/nextion.zip" -d "$tmp/x"
  local sum; sum="$(sha256sum "$tmp/x/NextionEditor.exe" | cut -d' ' -f1)"
  [ "$sum" = "$NEXTION_EXE_SHA256" ] || { rm -rf "$tmp"; die "NextionEditor.exe doğrulanamadı (SHA-256 uyuşmuyor)."; }
  mkdir -p "$DATA_DIR"
  cp -r "$tmp/x/." "$DATA_DIR/"
  rm -rf "$tmp"
  info "Editör kuruldu: $DATA_DIR"
}

# ---------------------------------------------------------------- Wine ortamı
setup_prefix() {
  [ -f "$WINEPREFIX/.nextion-ready" ] && return 0
  if [ ! -d "$WINEPREFIX/drive_c" ]; then
    info "Wine ortamı oluşturuluyor: $WINEPREFIX"
    WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init
    wait_wine
  fi
  # Not: wine-mono bu uygulamayla çalışmaz (şifreli modülü yüklerken çöker); gerçek .NET gerekir.
  info "Microsoft .NET 3.5 SP1 kuruluyor (tek seferlik, birkaç dakika sürer)..."
  winetricks -q dotnet35sp1
  wait_wine
  touch "$WINEPREFIX/.nextion-ready"
  info "Kurulum tamamlandı."
}

set_dpi() {
  local dpi="${NEXTION_DPI:-}" width=""
  if [ -z "$dpi" ]; then
    if command -v xrandr >/dev/null 2>&1; then
      width="$(xrandr 2>/dev/null | awk '/\*/ {split($1,a,"x"); if (a[1]+0>w) w=a[1]+0} END {print w+0}')"
    fi
    if   [ "${width:-0}" -ge 3800 ]; then dpi=192
    elif [ "${width:-0}" -ge 2500 ]; then dpi=144
    else dpi=96; fi
  fi
  local key
  for key in 'HKCC\Software\Fonts' 'HKCU\Control Panel\Desktop'; do   # Wine 10+ HKCC'yi okur
    wine reg add "$key" /v LogPixels /t REG_DWORD /d "$dpi" /f >/dev/null 2>&1 || true
  done
}

map_serial_ports() {
  local dosdev="$WINEPREFIX/dosdevices" n=20 p
  mkdir -p "$dosdev"
  find "$dosdev" -maxdepth 1 -name 'com2[0-9]' -type l -delete 2>/dev/null || true
  for p in /dev/ttyUSB* /dev/ttyACM*; do
    [ -e "$p" ] || continue
    n=$((n + 1))
    ln -sfn "$p" "$dosdev/com$n"
    info "Seri port: $p -> COM$n"
    if [ ! -w "$p" ]; then
      warn "$p için yazma izniniz yok. Çözüm: sudo usermod -aG dialout \"\$USER\" ve oturumu yeniden açın."
    fi
  done
}

# ---------------------------------------------------------------- menü kaydı
do_install() {
  local bin="$HOME/.local/bin/nextion-editor"
  local desktop="${XDG_DATA_HOME:-$HOME/.local/share}/applications/nextion-editor.desktop"
  mkdir -p "$(dirname "$bin")" "$(dirname "$desktop")"
  install -m 755 "$SCRIPT_PATH" "$bin"
  cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Nextion Editor
Comment=Nextion HMI ekran tasarım aracı (Wine)
Exec=$bin
Icon=applications-engineering
Terminal=false
Categories=Development;Electronics;
StartupWMClass=nextioneditor.exe
EOF
  update-desktop-database "$(dirname "$desktop")" >/dev/null 2>&1 || true
  info "Kuruldu: $bin"
  info "Uygulama menüsünde 'Nextion Editor' olarak görünecek."
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) warn "~/.local/bin PATH'te değil; komutu tam yoluyla çalıştırın.";; esac
}

do_uninstall() {
  rm -f "$HOME/.local/bin/nextion-editor" \
        "${XDG_DATA_HOME:-$HOME/.local/share}/applications/nextion-editor.desktop"
  info "Menü kaydı ve komut kaldırıldı."
  info "Wine ortamını da silmek için: rm -rf \"$WINEPREFIX\"   Editör dosyaları: $DATA_DIR"
}

# ---------------------------------------------------------------- ana akış
case "${1:-}" in
  -h|--help)    usage; exit 0 ;;
  --version)    echo "$VERSION"; exit 0 ;;
  --install)    do_install; exit 0 ;;
  --uninstall)  do_uninstall; exit 0 ;;
  --reset)      check_deps; info "Wine ortamı siliniyor: $WINEPREFIX"
                "$WINESERVER" -k 2>/dev/null || true; rm -rf "$WINEPREFIX"; shift ;;
  -*)           usage; exit 1 ;;
esac

[ "$(uname -s)" = "Linux" ] || warn "Bu betik yalnızca Ubuntu/Linux'ta test edilmiştir."
check_deps
find_app_dir
setup_prefix
set_dpi
map_serial_ports

info "Nextion Editor başlatılıyor ($APP_DIR)"
cd "$APP_DIR"   # editör yanındaki dll/bin dosyalarını çalışma dizininden okur
exec wine NextionEditor.exe "$@"
