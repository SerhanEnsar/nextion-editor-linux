<div align="center">

# Nextion Editor for Linux

**Nextion Editor (LTS)'u Ubuntu'da tek komutla çalıştırın.**

[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Linux-E95420?logo=ubuntu&logoColor=white)](#gereksinimler)
[![Wine](https://img.shields.io/badge/Wine-10.0-722F37?logo=wine&logoColor=white)](https://www.winehq.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/SerhanEnsar/nextion-editor-linux)](https://github.com/SerhanEnsar/nextion-editor-linux/releases/latest)

[Türkçe](#türkçe) · [English](#english)

</div>

---

## Türkçe

[Nextion](https://nextion.tech/) HMI ekranlarının resmi tasarım aracı **Nextion Editor** yalnızca Windows'ta çalışır.
Bu proje, editörü **Wine + Microsoft .NET 3.5 SP1** üzerinde, sisteminizdeki diğer Wine kurulumlarından
ayrı bir ortamda çalıştıran bir başlatıcıdır. Kurulumu, ölçeklemeyi ve seri port eşlemesini sizin yerinize yapar.

### Özellikler

- **Tek komutla kurulum:** Wine ortamını oluşturur, .NET 3.5 SP1'i kurar ve editörü başlatır.
- **Resmi kaynaktan indirme:** Editör dosyaları bulunamazsa `nextion.tech` adresinden indirilir ve SHA-256 ile doğrulanır.
- **HiDPI desteği:** Ekran çözünürlüğüne göre arayüzü otomatik ölçekler (%100, %150 veya %200).
- **Ekrana yükleme (Upload):** `/dev/ttyUSB*` ve `/dev/ttyACM*` adaptörlerini otomatik olarak `COM21`, `COM22`… portlarına eşler.
- **Uygulama menüsü kaydı:** `--install` ile editör GNOME/KDE menüsüne eklenir.
- **Yalıtılmış ortam:** Her şey `~/.wine-nextion` içinde kalır; mevcut `~/.wine` ortamınıza dokunulmaz.

### Gereksinimler

| | |
|---|---|
| İşletim sistemi | Ubuntu 22.04 veya üstü (Ubuntu 26.04 + Wine 10.0 ile test edildi) |
| Paketler | `wine`, `winetricks`, `curl`, `unzip`, `cabextract` |
| Disk | Yaklaşık 1 GB (Wine ortamı + .NET) |

### Kurulum

```bash
# 1. Bağımlılıkları kurun
sudo apt update
sudo apt install wine winetricks curl unzip cabextract

# 2. Ekrana USB üzerinden yükleme yapacaksanız seri port izni verin
#    (sonra oturumu kapatıp yeniden açın)
sudo usermod -aG dialout "$USER"

# 3. Başlatıcıyı indirin
curl -fLO https://github.com/SerhanEnsar/nextion-editor-linux/releases/latest/download/nextion.sh
chmod +x nextion.sh

# 4. Uygulama menüsüne ekleyin (isteğe bağlı) ve çalıştırın
./nextion.sh --install
./nextion.sh
```

İlk çalıştırmada .NET kurulumu birkaç dakika sürer. Sonraki açılışlar birkaç saniyede gerçekleşir.

> **Elinizde Nextion Editor klasörü zaten varsa** (ör. `nextion-setup-vLTS`), `nextion.sh` dosyasını
> o klasöre koyun ya da `NEXTION_DIR=/klasör/yolu ./nextion.sh` ile çalıştırın. Bu durumda editör tekrar indirilmez.

### Kullanım

```text
./nextion.sh              Gerekirse kurulumu yapar ve editörü başlatır
./nextion.sh --install    ~/.local/bin/nextion-editor komutunu ve menü kaydını oluşturur
./nextion.sh --uninstall  Menü kaydını ve komutu kaldırır
./nextion.sh --reset      Wine ortamını silip baştan kurar
./nextion.sh --help       Yardımı gösterir
```

| Ortam değişkeni | Açıklama | Varsayılan |
|---|---|---|
| `NEXTION_DPI` | Arayüz ölçeği: `96` (%100), `144` (%150), `192` (%200) | Otomatik |
| `NEXTION_DIR` | `NextionEditor.exe`'nin bulunduğu klasör | Otomatik |
| `WINEPREFIX` | Kullanılacak Wine ortamı | `~/.wine-nextion` |

### Ekrana yükleme

**USB-TTL ile (Upload):** Adaptörü taktıktan sonra editörü başlatın. Terminalde `Seri port: /dev/ttyUSB0 -> COM21`
gibi bir satır görürsünüz. Editörde **Upload** penceresinden bu COM portunu seçin.

**microSD kart ile:** **File → TFT file output** ile `.tft` dosyasını dışa aktarın. Dosyayı FAT32 biçimli bir
microSD kartın köküne kopyalayın, kartı ekrana takıp gücü verin.

### Sorun giderme

<details>
<summary><b>Arayüz çok küçük ya da çok büyük</b></summary>

Ölçeği elle seçin: `NEXTION_DPI=144 ./nextion.sh`
</details>

<details>
<summary><b>Upload sırasında port açılamıyor</b></summary>

Kullanıcınızın `dialout` grubunda olduğunu doğrulayın: `id -nG | grep dialout`. Grupta değilseniz
`sudo usermod -aG dialout "$USER"` komutunu çalıştırıp oturumu yeniden açın. Adaptörü editörü
başlatmadan **önce** takın.
</details>

<details>
<summary><b>"wineserver bulunamadı" hatası</b></summary>

Yolunu belirtin: `WINESERVER=$(dpkg -L wine64 libwine | grep '/wineserver$' | head -1) ./nextion.sh`
</details>

<details>
<summary><b>.NET kurulumu yarıda kaldı ya da editör açılmıyor</b></summary>

Ortamı sıfırlayın: `./nextion.sh --reset`. Ayrıntılı log almak için: `WINEDEBUG=err+all ./nextion.sh`
</details>

<details>
<summary><b>Sağ altta "Failed to connect server" yazıyor</b></summary>

Zararsızdır. Editör, artık kullanılmayan güncelleme sunucusuna bağlanamıyor.
</details>

<details>
<summary><b>Neden wine-mono değil de Microsoft .NET?</b></summary>

Nextion Editor açılışta şifreli bir modül (`ApplicationRUN.bin`) açıp yüklüyor. wine-mono bu modülü yüklerken
çöküyor; Microsoft .NET 3.5 SP1 ise sorunsuz çalıştırıyor.
</details>

### macOS

macOS henüz desteklenmiyor. Mac'te en güvenilir seçenekler CrossOver ya da bir Windows sanal makinesi
(UTM veya Parallels). Katkılara açığız.

### Yasal uyarı

Bu depo **yalnızca başlatıcı betiği** içerir. Nextion Editor, Nextion® markası ve ilgili dosyalar
ITEAD Studio'ya aittir; bu depo onlarla bağlantılı değildir. Editör, kullanıcının bilgisayarına doğrudan
resmi siteden indirilir ve bu depoda dağıtılmaz.

---

## English

A launcher that runs the Windows-only **Nextion Editor (LTS)** on Ubuntu using **Wine + Microsoft .NET 3.5 SP1**
in an isolated prefix (`~/.wine-nextion`).

**What it does:**
- Downloads the editor from the official `nextion.tech` site and verifies it with SHA-256.
- Installs .NET 3.5 SP1.
- Scales the UI on HiDPI displays.
- Maps USB serial adapters to `COM21+` so you can upload to the display.

```bash
sudo apt install wine winetricks curl unzip cabextract
sudo usermod -aG dialout "$USER"     # for uploading over USB; log out and back in afterwards
curl -fLO https://github.com/SerhanEnsar/nextion-editor-linux/releases/latest/download/nextion.sh
chmod +x nextion.sh
./nextion.sh --install               # optional: add to the application menu
./nextion.sh
```

| Variable | Description |
|---|---|
| `NEXTION_DPI` | UI scale: 96 / 144 / 192 (auto-detected by default) |
| `NEXTION_DIR` | Use an existing Nextion Editor folder instead of downloading it |

Tested on Ubuntu 26.04 with Wine 10.0. This repository contains only the launcher script. Nextion Editor
belongs to ITEAD Studio and is not redistributed here.

## License

[MIT](LICENSE). This license covers the launcher script only.
