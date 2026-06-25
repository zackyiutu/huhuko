#!/bin/bash
# ============================================================
#  VPS BACKUP SYSTEM (Termux compatible - no sudo)
# ============================================================
set -e

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
BACKUP_DIR="$HOME/vps-backup"

install_rclone() {
    command -v rclone &>/dev/null || {
        if [ -d /data/data/com.termux ]; then
            curl -s https://rclone.org/install.sh | bash 2>/dev/null || pip install rclone
        else
            curl -s https://rclone.org/install.sh | bash
        fi
    }
}

backup() {
    echo -e "\n${CYAN}  ╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║     💾 BACKUP VPS                     ║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════╝${NC}\n"
    install_rclone
    mkdir -p "$BACKUP_DIR"

    echo -e "  📁 Backing up home..."
    rsync -a --exclude='.cache' --exclude='node_modules' --exclude='__pycache__' \
        --exclude='.npm' --exclude='.nvm' --exclude='vps-backup' \
        "$HOME/" "$BACKUP_DIR/home/" 2>/dev/null || true

    echo -e "  📋 Saving package lists..."
    dpkg --get-selections > "$BACKUP_DIR/packages.list" 2>/dev/null || true
    pip list --format=freeze > "$BACKUP_DIR/pip-packages.txt" 2>/dev/null || true
    npm list -g --depth=0 > "$BACKUP_DIR/npm-packages.txt" 2>/dev/null || true
    crontab -l > "$BACKUP_DIR/crontab.txt" 2>/dev/null || true
    echo "backup_date=$(date -Iseconds)" > "$BACKUP_DIR/manifest.txt"

    if rclone listremotes 2>/dev/null | grep -q "gdrive:"; then
        echo -e "  ☁️  Uploading ke Google Drive..."
        rclone sync "$BACKUP_DIR" gdrive:vps-backup --progress --transfers 4
        echo -e "\n${GREEN}  ✅ Backup selesai!${NC}"
    else
        echo -e "\n${YELLOW}  ⚠️  Google Drive belum di-setup.${NC}"
        echo -e "  Backup lokal: $BACKUP_DIR"
    fi

    # Recovery script
    cat > "$HOME/restore.sh" << 'RESTORE'
#!/bin/bash
echo "🔄 Restoring..."
command -v rclone &>/dev/null || curl -s https://rclone.org/install.sh | bash 2>/dev/null || pip install rclone
mkdir -p ~/vps-backup
rclone sync gdrive:vps-backup ~/vps-backup --progress 2>/dev/null || { echo "❌ GDrive not configured"; exit 1; }
[ -d ~/vps-backup/home ] && rsync -a ~/vps-backup/home/ ~/
[ -f ~/vps-backup/pip-packages.txt ] && pip install -r ~/vps-backup/pip-packages.txt 2>/dev/null || true
echo "✅ Restore complete!"
RESTORE
    chmod +x "$HOME/restore.sh"
    echo -e "  📄 Recovery: ~/restore.sh"
}

recover() {
    echo -e "\n${CYAN}  ═══ RECOVERY ═══${NC}\n"
    install_rclone
    if ! rclone listremotes 2>/dev/null | grep -q "gdrive:"; then
        echo -e "  ❌ Google Drive belum di-setup"
        return 1
    fi
    mkdir -p "$BACKUP_DIR"
    rclone sync gdrive:vps-backup "$BACKUP_DIR" --progress
    [ -d "$BACKUP_DIR/home" ] && rsync -a "$BACKUP_DIR/home/" "$HOME/"
    [ -f "$BACKUP_DIR/pip-packages.txt" ] && pip install -r "$BACKUP_DIR/pip-packages.txt" 2>/dev/null || true
    echo -e "\n${GREEN}  ✅ Recovery complete!${NC}"
}

auto_backup() {
    echo -e "${CYAN}  ⏰ Auto-backup setiap 1 jam...${NC}"
    cat > "$HOME/.auto-backup.sh" << 'AB'
#!/bin/bash
BD="$HOME/vps-backup"; mkdir -p "$BD"
rsync -a --exclude='.cache' --exclude='node_modules' "$HOME/" "$BD/home/" 2>/dev/null
dpkg --get-selections > "$BD/packages.list" 2>/dev/null
pip list --format=freeze > "$BD/pip-packages.txt" 2>/dev/null
echo "backup_date=$(date -Iseconds)" > "$BD/manifest.txt"
rclone sync "$BD" gdrive:vps-backup --quiet 2>/dev/null
AB
    chmod +x "$HOME/.auto-backup.sh"
    (crontab -l 2>/dev/null; echo "0 * * * * $HOME/.auto-backup.sh") | crontab -
    echo -e "${GREEN}  ✅ Auto-backup aktif!${NC}"
}

case "${1:-}" in
    backup) backup ;;
    recover|restore) recover ;;
    auto-backup) auto_backup ;;
    *) echo "Usage: bash backup.sh [backup|recover|auto-backup]" ;;
esac
