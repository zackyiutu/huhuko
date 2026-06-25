#!/bin/bash
# ============================================================
#  GOOGLE DRIVE SETUP - Service Account (No OAuth)
#  Works on Termux (no sudo needed)
# ============================================================
set -e

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║     ☁️  GOOGLE DRIVE SETUP                         ║"
echo "  ║     Service Account | No OAuth | 5TB Storage      ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Install rclone (Termux compatible - no sudo)
if ! command -v rclone &>/dev/null; then
    echo -e "${CYAN}[1/3] Installing rclone...${NC}"
    # Termux direct install (no sudo)
    if [ -d /data/data/com.termux ]; then
        curl -s https://rclone.org/install.sh | bash 2>/dev/null || {
            echo "  Manual install:"
            echo "  pkg install rclone 2>/dev/null || pip install rclone"
            pip install rclone 2>/dev/null || true
        }
    else
        curl -s https://rclone.org/install.sh | bash
    fi
fi
echo -e "${GREEN}  ✅ rclone ready${NC}"

# Python deps
pip install --quiet google-api-python-client google-auth 2>/dev/null || true

# Setup script
echo -e "${CYAN}[2/3] Generating setup script...${NC}"
cat > ~/setup-gdrive.py << 'PYEOF'
#!/usr/bin/env python3
"""Google Drive Service Account Setup - No OAuth."""
import os, json, sys, subprocess
from pathlib import Path

def setup(sa_json_path, folder_id=None):
    sa_path = Path(sa_json_path).expanduser()
    if not sa_path.exists():
        print(f"❌ File tidak ditemukan: {sa_path}"); return False
    with open(sa_path) as f:
        sa = json.load(f)
    email = sa.get("client_email", "")
    print(f"📧 Service Account: {email}")

    config_path = Path.home() / ".config" / "rclone" / "rclone.conf"
    config_path.parent.mkdir(parents=True, exist_ok=True)
    cfg = f"[gdrive]\ntype = drive\nscope = drive\nservice_account_file = {sa_path}\n"
    if folder_id:
        cfg += f"root_folder_id = {folder_id}\n"
    config_path.write_text(cfg)
    print(f"✅ rclone config: {config_path}")

    r = subprocess.run(["rclone", "lsd", "gdrive:"], capture_output=True, text=True)
    if r.returncode == 0:
        print("✅ Google Drive connected!")
        return True
    else:
        print(f"⚠️  Share folder ke email: {email}")
        print(f"   (Google Drive → klik kanan folder → Share → add email)")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 setup-gdrive.py <path-to-sa.json> [folder-id]")
        print("\nCara dapat SA JSON:")
        print("  1. https://console.cloud.google.com")
        print("  2. Buat project → Enable Drive API")
        print("  3. IAM → Service Accounts → Create")
        print("  4. Keys → Add Key → JSON → Download")
    else:
        folder_id = sys.argv[2] if len(sys.argv) > 2 else None
        setup(sys.argv[1], folder_id)
PYEOF
chmod +x ~/setup-gdrive.py
echo -e "${GREEN}  ✅ ~/setup-gdrive.py${NC}"

# Mount script (Termux compatible)
echo -e "${CYAN}[3/3] Generating mount script...${NC}"
cat > ~/mount-gdrive.sh << 'MOUNT'
#!/bin/bash
# Mount Google Drive (Termux compatible - no sudo)
command -v rclone &>/dev/null || curl -s https://rclone.org/install.sh | bash 2>/dev/null || pip install rclone

# Termux: mount ke home, bukan /mnt
if [ -d /data/data/com.termux ]; then
    MOUNT_POINT="$HOME/gdrive"
else
    MOUNT_POINT="/mnt/gdrive"
fi

mkdir -p "$MOUNT_POINT"
rclone mount gdrive: "$MOUNT_POINT" --daemon --vfs-cache-mode full --vfs-cache-max-size 2G --allow-other --allow-non-empty 2>/dev/null
sleep 2

if mountpoint -q "$MOUNT_POINT" 2>/dev/null || ls "$MOUNT_POINT" &>/dev/null; then
    echo "✅ Google Drive mounted di $MOUNT_POINT"
    ls "$MOUNT_POINT" | head -10
else
    echo "❌ Mount gagal. Setup dulu: python3 ~/setup-gdrive.py <sa.json>"
fi
MOUNT
chmod +x ~/mount-gdrive.sh
echo -e "${GREEN}  ✅ ~/mount-gdrive.sh${NC}"

echo ""
echo -e "${GREEN}  ═══ SETUP SELESAI ═══${NC}"
echo -e "  Di VPS jalankan:"
echo -e "    ${YELLOW}1.${NC} Copy SA JSON ke VPS"
echo -e "    ${YELLOW}2.${NC} python3 ~/setup-gdrive.py /path/to/sa.json"
echo -e "    ${YELLOW}3.${NC} bash ~/mount-gdrive.sh"
