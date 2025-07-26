#!/bin/bash

# 🌐 Aktifkan NVM dan CLI
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm use 20 > /dev/null
export PATH="$PATH:$(npm bin -g)"

# 📁 Path penting
NODE_PATH=$(which node)
SERVICE_FILE="/etc/systemd/system/netrum-node.service"
SYNC_SCRIPT="/root/netrum-lite-node/src/system/sync/service.js"
MINING_LOG="$NODE_PATH-log"

# 🔧 Perbaikan service systemd
fix_service() {
    echo "🔧 Memperbaiki konfigurasi service..."
    if [ -f "$SERVICE_FILE" ]; then
        sudo sed -i "s|ExecStart=.*|ExecStart=$NODE_PATH $SYNC_SCRIPT|" "$SERVICE_FILE"
        sudo systemctl daemon-reexec
        sudo systemctl daemon-reload
    else
        echo "❌ File service tidak ditemukan: $SERVICE_FILE"
        return 1
    fi
}

# 🚀 Jalankan sync service
start_sync() {
    echo "🚀 Menjalankan Netrum Sync Service..."
    sudo systemctl restart netrum-node.service
    sleep 2
    STATUS=$(systemctl is-active netrum-node.service)
    if [ "$STATUS" != "active" ]; then
        echo "❌ Gagal menjalankan service. Detail:"
        sudo systemctl status netrum-node.service
        return 1
    fi
    echo "✅ Sync service aktif."
}

# 🔧 Perbaiki permission log mining
fix_log_permission() {
    if [ -f "$MINING_LOG" ]; then
        chmod +x "$MINING_LOG"
    fi
}

# 🧰 Setup awal
setup_awal() {
    echo "🔧 Menjalankan setup awal..."
    sudo apt purge nodejs npm -y
    sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
    sudo apt install -y curl bc jq speedtest-cli python3-venv python3-full
    python3 -m venv ~/venv
    source ~/venv/bin/activate
    pip install speedtest-cli
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    source "$NVM_DIR/nvm.sh"
    nvm install 20
    nvm use 20
    git clone https://github.com/NetrumLabs/netrum-lite-node.git
    cd netrum-lite-node
    npm install
    npm link
    netrum
    netrum-system
}

# 🧾 Setup wallet
setup_wallet() {
    echo ""
    echo "🧾 Wallet Setup"
    echo "1️⃣ Buat wallet baru"
    echo "2️⃣ Impor wallet lama"
    read -p "Pilih (1/2): " WALLET_OPTION

    if [ "$WALLET_OPTION" == "1" ]; then
        netrum-new-wallet > ~/netrum-wallet.txt
        PRIVATE_KEY=$(grep -i "Private Key" ~/netrum-wallet.txt | awk '{print $NF}')
        echo "$PRIVATE_KEY" > ~/netrum-private-key.txt
        echo "✅ Wallet baru dibuat. Backup file di ~/netrum-wallet.txt dan ~/netrum-private-key.txt"
    elif [ "$WALLET_OPTION" == "2" ]; then
        read -p "🔑 Masukkan private key ETH kamu: " IMPORT_KEY
        echo "$IMPORT_KEY" > ~/netrum-private-key.txt
        netrum-import-wallet "$IMPORT_KEY"
        echo "✅ Wallet berhasil diimpor."
    else
        echo "❌ Pilihan tidak valid."
        return
    fi

    read -p "Sudah backup wallet? Lanjutkan? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        echo "⏹️ Setup wallet dihentikan."
        exit 0
    fi
}

# 📝 Registrasi node
register_node() {
    netrum-check-basename
    netrum-node-id

    echo ""
    echo "💸 Pastikan kamu sudah mengirim minimal 0.0005 BASE ke wallet kamu."
    read -p "Sudah isi BASE? Lanjutkan registrasi? (y/n): " BASE_READY
    if [ "$BASE_READY" != "y" ]; then
        echo "⏹️ Registrasi dihentikan."
        exit 0
    fi

    echo "📝 Registering node..."
    netrum-node-register

    echo "⏳ Menunggu 10 detik agar file node ID dibuat..."
    sleep 10

    echo "✍️ Generating signature..."
    netrum-node-sign
}

# ⛏️ Sync dan mining
start_mining() {
    fix_service && start_sync && fix_log_permission
    echo "⏳ Menunggu 5 menit untuk sync..."
    sleep 300
    echo "⛏️ Menjalankan mining..."
    netrum-mining
    echo "📄 Log mining:"
    netrum-mining-log
    echo "💼 Wallet info:"
    netrum-wallet
}

# 🎛️ Menu utama
while true; do
    echo ""
    echo "╭───────────────────────────────╮"
    echo "│     🚀 Netrum Setup Menu      │"
    echo "╰───────────────────────────────╯"
    echo "1️⃣ Setup awal (install & clone)"
    echo "2️⃣ Setup wallet (baru/impor)"
    echo "3️⃣ Registrasi node"
    echo "4️⃣ Sync & mulai mining"
    echo "5️⃣ Keluar"
    read -p "Pilih menu (1-5): " MENU

    case $MENU in
        1) setup_awal ;;
        2) setup_wallet ;;
        3) register_node ;;
        4) start_mining ;;
        5) echo "👋 Keluar dari menu."; exit 0 ;;
        *) echo "❌ Pilihan tidak valid." ;;
    esac
done
