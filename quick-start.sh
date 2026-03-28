#!/bin/bash

# AFFiNE Modular - 快速啟動腳本

# 一鍵啟動完整環境（PostgreSQL + Ollama + AFFiNE）



set -e



echo "🚀 AFFiNE Modular 快速啟動"

echo "=============================="



# 顏色

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

RED='\033[0;31m'

NC='\033[0m'



# 檢查並啟動 PostgreSQL

if ! pgrep -x "postgres" > /dev/null; then

    echo -e "${YELLOW}▶${NC} 啟動 PostgreSQL..."

    if command -v brew &> /dev/null; then

        brew services start postgresql@15

    else

        pg_ctl -D /usr/local/var/postgres start

    fi

    sleep 3

    echo -e "${GREEN}✓${NC} PostgreSQL 已啟動"

else

    echo -e "${GREEN}✓${NC} PostgreSQL 已在運行"

fi



# 檢查並啟動 Ollama

if ! pgrep -x "ollama" > /dev/null; then

    echo -e "${YELLOW}▶${NC} 啟動 Ollama..."

    if command -v brew &> /dev/null; then

        brew services start ollama

    else

        ollama serve &

    fi

    sleep 3

    echo -e "${GREEN}✓${NC} Ollama 已啟動"



    # 檢查模型

    echo -e "${YELLOW}▶${NC} 檢查模型..."

    ollama list | grep -q "llama3.2" || echo -e "${YELLOW}!${NC} 建議運行: ollama pull llama3.2"

    ollama list | grep -q "nomic-embed-text" || echo -e "${YELLOW}!${NC} 建議運行: ollama pull nomic-embed-text"

else

    echo -e "${GREEN}✓${NC} Ollama 已在運行"

fi



echo ""

echo -e "${GREEN}✓${NC} 所有服務已就緒！"

echo ""



# 顯示狀態

echo "📊 系統狀態:"

echo "   PostgreSQL: $(pgrep -x postgres > /dev/null && echo '✅ 運行中' || echo '❌ 未運行')"

echo "   Ollama:     $(pgrep -x ollama > /dev/null && echo '✅ 運行中' || echo '❌ 未運行')"

echo ""



# 選擇啟動模式

echo "🎯 選擇啟動模式:"

echo "   1) 🖥️  桌面端開發 (yarn workspace @affine/electron dev)"

echo "   2) 🌐 Web 端開發 (yarn workspace @affine/web dev)"

echo "   3) 📦 構建生產版本 (yarn build)"

echo "   4) 🔧 僅檢查環境"

echo ""



read -p "請選擇 (1-4): " choice



case $choice in

    1)

        echo -e "${GREEN}▶${NC} 啟動桌面端開發模式..."

        yarn workspace @affine/electron dev

        ;;

    2)

        echo -e "${GREEN}▶${NC} 啟動 Web 端開發模式..."

        yarn workspace @affine/web dev

        ;;

    3)

        echo -e "${GREEN}▶${NC} 開始構建生產版本..."

        yarn build

        echo -e "${GREEN}✓${NC} 構建完成！輸出在目錄: dist/"

        ;;

    4)

        echo -e "${GREEN}✓${NC} 環境檢查完成"

        ;;

    *)

        echo -e "${YELLOW}!${NC} 無效選擇，退出"

        exit 1

        ;;

esac
