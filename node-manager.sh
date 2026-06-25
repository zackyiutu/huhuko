#!/bin/bash
# ============================================================
#  VPS NODE MANAGER
#  Kelola semua VPS nodes dari 1 layar Termux
# ============================================================
set -e

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
NODES_FILE="$HOME/.config/free_vps/nodes.txt"
mkdir -p "$(dirname "$NODES_FILE")"

list_nodes() {
    [ ! -f "$NODES_FILE" ] || [ ! -s "$NODES_FILE" ] && echo -e "${YELLOW}  Belum ada node.${NC}" && return 1
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              VPS NODES                            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}\n"
    local n=0
    while IFS='|' read -r id ssh status ts; do
        [ -z "$id" ] && continue
        n=$((n+1))
        echo -e "  ${BOLD}[$n]${NC} ${GREEN}$id${NC} | SSH: ${CYAN}$ssh${NC} | $status"
    done < "$NODES_FILE"
    echo -e "\n  Total: ${BOLD}$n nodes${NC}\n"
}

add_node() {
    echo -e "\n${CYAN}═══ Tambah Node ═══${NC}\n"
    read -p "  Node ID: " nid
    read -p "  SSH string: " ssh
    [ -z "$nid" ] || [ -z "$ssh" ] && echo -e "${RED}❌ Input kosong${NC}" && return
    echo "$nid|$ssh|online|$(date '+%Y-%m-%d %H:%M')" >> "$NODES_FILE"
    echo -e "${GREEN}✅ Node $nid ditambahkan${NC}"
}

connect_node() {
    list_nodes || return
    read -p "  Nomor node: " num
    local line=$(sed -n "${num}p" "$NODES_FILE")
    [ -z "$line" ] && echo -e "${RED}❌ Node tidak ditemukan${NC}" && return
    local ssh=$(echo "$line" | cut -d'|' -f2)
    local id=$(echo "$line" | cut -d'|' -f1)
    echo -e "${GREEN}Connecting ke $id...${NC}"
    echo -e "${YELLOW}Tekan 'q' atau Ctrl+C setelah tmate messages${NC}\n"
    ssh "$ssh"
}

connect_all() {
    [ ! -f "$NODES_FILE" ] || [ ! -s "$NODES_FILE" ] && echo -e "${YELLOW}Tidak ada node.${NC}" && return
    echo -e "${CYAN}Membuka semua node di tmux windows...${NC}"
    tmux new-session -d -s vps 2>/dev/null || true
    local n=0
    while IFS='|' read -r id ssh status ts; do
        [ -z "$id" ] && continue
        n=$((n+1))
        tmux new-window -t vps -n "$id" "ssh $ssh; bash" 2>/dev/null || true
        echo -e "  ${GREEN}✅ $id${NC}"
    done < "$NODES_FILE"
    echo -e "\n${GREEN}$n nodes dibuka!${NC}"
    echo -e "Attach: ${CYAN}tmux attach -t vps${NC}"
    echo -e "Switch: ${CYAN}Ctrl+B lalu angka${NC}\n"
}

remove_node() {
    list_nodes || return
    read -p "  Hapus nomor: " num
    sed -i "${num}d" "$NODES_FILE"
    echo -e "${GREEN}✅ Dihapus${NC}"
}

echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     VPS NODE MANAGER                              ║${NC}"
echo -e "${CYAN}║     Kelola 20 VPS dari 1 layar Termux             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}\n"

case "${1:-}" in
    list|ls) list_nodes ;;
    add) add_node ;;
    connect|c) connect_node ;;
    all) connect_all ;;
    remove|rm) remove_node ;;
    *)
        echo "Commands:"
        echo "  bash node-manager.sh          Interactive mode"
        echo "  bash node-manager.sh list     Lihat nodes"
        echo "  bash node-manager.sh add      Tambah node"
        echo "  bash node-manager.sh connect  Connect ke node"
        echo "  bash node-manager.sh all      Buka semua di tmux"
        echo "  bash node-manager.sh remove   Hapus node"
        echo ""
        # Interactive
        while true; do
            read -p "node-manager> " cmd
            case "$cmd" in
                list|ls) list_nodes ;;
                add) add_node ;;
                connect|c) connect_node ;;
                all) connect_all ;;
                remove|rm) remove_node ;;
                clear) > "$NODES_FILE"; echo -e "${GREEN}✅ Cleared${NC}" ;;
                exit|quit) break ;;
                *) [ -n "$cmd" ] && echo "Unknown: $cmd" ;;
            esac
        done
        ;;
esac
