#!/bin/bash

# AFFiNE 魔改專屬版本 - 全自動設置腳本

# 功能：本地LLM + 向量數據庫 + MCP工具 + 插拔式模組

# 適用平台：macOS + iOS（保留）



set -e



echo "╔══════════════════════════════════════════════════════════╗"

echo "║       🚀 AFFiNE Modular Edition - 魔改專屬版本           ║"

echo "║       本地LLM + 向量數據庫 + MCP 一鍵部署                 ║"

echo "╚══════════════════════════════════════════════════════════╝"

echo ""



# 顏色定義

RED='\033[0;31m'

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

BLUE='\033[0;34m'

NC='\033[0m' # No Color



# 配置路徑

AFFINE_HOME="${HOME}/.affine"

CONFIG_FILE="${AFFINE_HOME}/modules.json"

OLLAMA_MODELS="${HOME}/.ollama/models"



# ============================================

# 步驟 1: 環境檢查

# ============================================

check_environment() {

    echo -e "${BLUE}[1/6]${NC} 檢查系統環境..."
    

    
    # 檢查 macOS
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
    
        echo -e "${RED}✗${NC} 此腳本僅支持 macOS"
        
        exit 1
        
    fi
    
    echo -e "${GREEN}✓${NC} macOS 檢測通過"
    

    
    # 檢查 Homebrew
    
    if ! command -v brew &> /dev/null; then
    
        echo -e "${YELLOW}!${NC} Homebrew 未安裝，開始安裝..."
        
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
    fi
    
    echo -e "${GREEN}✓${NC} Homebrew 已就緒"
    

    
    # 檢查 Node.js
    
    if ! command -v node &> /dev/null; then
    
        echo -e "${YELLOW}!${NC} Node.js 未安裝，開始安裝..."
        
        brew install node@22
        
        brew link node@22 --force
        
    fi
    
    echo -e "${GREEN}✓${NC} Node.js $(node -v)"
    

    
    # 檢查 Yarn
    
    if ! command -v yarn &> /dev/null; then
    
        echo -e "${YELLOW}!${NC} Yarn 未安裝，開始安裝..."
        
        npm install -g yarn
        
    fi
    
    echo -e "${GREEN}✓${NC} Yarn $(yarn -v)"
    

    
    # 檢查 Rust
    
    if ! command -v cargo &> /dev/null; then
    
        echo -e "${YELLOW}!${NC} Rust 未安裝，開始安裝..."
        
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        source "$HOME/.cargo/env"
        
    fi
    
    echo -e "${GREEN}✓${NC} Rust $(rustc --version)"
    
}



# ============================================

# 步驟 2: 清理不必要文件（保留macOS+iOS）

# ============================================

cleanup_repository() {

    echo ""
    
    echo -e "${BLUE}[2/6]${NC} 清理倉庫（保留 macOS + iOS）..."
    

    
    local removed_count=0
    

    
    # 刪除開發環境配置
    
    for dir in .codesandbox .devcontainer .docker; do
    
        if [ -d "$dir" ]; then
        
            rm -rf "$dir"
            
            echo -e "${GREEN}✓${NC} 刪除: $dir"
            
            ((removed_count++))
            
        fi
        
    done
    

    
    # 刪除 Android（保留 iOS）
    
    if [ -d "packages/frontend/apps/android" ]; then
    
        rm -rf packages/frontend/apps/android
        
        echo -e "${GREEN}✓${NC} 刪除: packages/frontend/apps/android"
        
        ((removed_count++))
        
    fi
    

    
    # 刪除測試和文檔
    
    for dir in tests docs blocksuite/docs blocksuite/integration-test blocksuite/playground; do
    
        if [ -d "$dir" ]; then
        
            rm -rf "$dir"
            
            echo -e "${GREEN}✓${NC} 刪除: $dir"
            
            ((removed_count++))
            
        fi
        
    done
    

    
    # 刪除開發工具
    
    for dir in tools/changelog tools/commitlint tools/doc-diff tools/playstore-auto-bump; do
    
        if [ -d "$dir" ]; then
        
            rm -rf "$dir"
            
            echo -e "${GREEN}✓${NC} 刪除: $dir"
            
            ((removed_count++))
            
        fi
        
    done
    

    
    echo -e "${GREEN}✓${NC} 清理完成，共移除 $removed_count 個目錄"
    
}



# ============================================

# 步驟 3: 安裝 PostgreSQL + pgvector

# ============================================

setup_database() {

    echo ""
    
    echo -e "${BLUE}[3/6]${NC} 設置向量數據庫..."
    

    
    # 安裝 PostgreSQL
    
    if ! brew list postgresql@15 &>/dev/null; then
    
        echo -e "${YELLOW}!${NC} 安裝 PostgreSQL 15..."
        
        brew install postgresql@15
        
        brew services start postgresql@15
        
        sleep 3
        
    fi
    
    echo -e "${GREEN}✓${NC} PostgreSQL 已安裝"
    

    
    # 安裝 pgvector
    
    if ! brew list pgvector &>/dev/null; then
    
        echo -e "${YELLOW}!${NC} 安裝 pgvector 擴展..."
        
        brew install pgvector
        
    fi
    
    echo -e "${GREEN}✓${NC} pgvector 已安裝"
    

    
    # 創建數據庫和用戶
    
    local pg_ctl_path="$(brew --prefix postgresql@15)/bin/pg_ctl"
    
    local psql_path="$(brew --prefix postgresql@15)/bin/psql"
    

    
    # 確保服務運行
    
    if ! pgrep -x "postgres" > /dev/null; then
    
        $pg_ctl_path -D "$(brew --prefix postgresql@15)/var/postgres" start
        
        sleep 2
        
    fi
    

    
    # 創建用戶和數據庫
    
    $psql_path postgres -c "CREATE USER affine WITH SUPERUSER PASSWORD 'affine';" 2>/dev/null || echo -e "${YELLOW}!${NC} 用戶已存在"
    
    $psql_path postgres -c "CREATE DATABASE affine_vectors OWNER affine;" 2>/dev/null || echo -e "${YELLOW}!${NC} 數據庫已存在"
    
    $psql_path postgres -c "CREATE DATABASE affine OWNER affine;" 2>/dev/null || echo -e "${YELLOW}!${NC} 數據庫已存在"
    

    
    # 啟用 pgvector
    
    $psql_path -d affine_vectors -c "CREATE EXTENSION IF NOT EXISTS vector;"
    

    
    # 創建向量表
    
    $psql_path -d affine_vectors -c "
    
        CREATE TABLE IF NOT EXISTS document_chunks (
        
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            
            workspace_id VARCHAR(255),
            
            doc_id VARCHAR(255),
            
            block_id VARCHAR(255),
            
            content TEXT,
            
            embedding vector(768),
            
            metadata JSONB,
            
            created_at TIMESTAMP DEFAULT NOW()
            
        );
        
        CREATE INDEX IF NOT EXISTS idx_embedding ON document_chunks 
        
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
        
    "
    

    
    echo -e "${GREEN}✓${NC} 向量數據庫準備完成"
    
}



# ============================================

# 步驟 4: 安裝 Ollama + 下載模型

# ============================================

setup_ollama() {

    echo ""
    
    echo -e "${BLUE}[4/6]${NC} 設置本地 LLM..."
    

    
    # 安裝 Ollama
    
    if ! command -v ollama &> /dev/null; then
    
        echo -e "${YELLOW}!${NC} 安裝 Ollama..."
        
        brew install ollama
        
    fi
    
    echo -e "${GREEN}✓${NC} Ollama 已安裝"
    

    
    # 啟動服務
    
    if ! pgrep -x "ollama" > /dev/null; then
    
        echo -e "${YELLOW}!${NC} 啟動 Ollama 服務..."
        
        brew services start ollama
        
        sleep 3
        
    fi
    
    echo -e "${GREEN}✓${NC} Ollama 服務運行中"
    

    
    # 下載模型
    
    echo -e "${YELLOW}!${NC} 下載 LLM 模型..."
    
    ollama pull llama3.2 || echo -e "${YELLOW}!${NC} llama3.2 可能已存在"
    
    ollama pull nomic-embed-text || echo -e "${YELLOW}!${NC} nomic-embed-text 可能已存在"
    

    
    echo -e "${GREEN}✓${NC} 模型準備完成"
    
}



# ============================================

# 步驟 5: 創建模組配置

# ============================================

setup_modules() {

    echo ""
    
    echo -e "${BLUE}[5/6]${NC} 創建模組配置..."
    

    
    mkdir -p "$AFFINE_HOME"
    

    
    cat > "$CONFIG_FILE" << 'EOF'
    
{

  "version": "1.0.0",
  
  "description": "AFFiNE Modular Configuration - 插拔式模組配置",
  
  "modules": {
  
    "local-llm": {
    
      "enabled": true,
      
      "name": "本地 LLM",
      
      "description": "使用 Ollama 運行本地大語言模型",
      
      "settings": {
      
        "provider": "ollama",
        
        "host": "http://localhost:11434",
        
        "model": "llama3.2",
        
        "embeddingModel": "nomic-embed-text",
        
        "temperature": 0.7,
        
        "maxTokens": 4096,
        
        "contextWindow": 8192,
        
        "useGPU": true,
        
        "quantization": "q4_0",
        
        "systemPrompt": "你是一個專業的知識管理助手，擅長整理、分析和總結文檔內容。請用簡潔專業的方式回答問題。"
        
      }
      
    },
    
    "vector-store": {
    
      "enabled": true,
      
      "name": "向量存儲",
      
      "description": "PostgreSQL + pgvector 向量數據庫",
      
      "settings": {
      
        "host": "localhost",
        
        "port": 5432,
        
        "database": "affine_vectors",
        
        "username": "affine",
        
        "password": "affine",
        
        "dimensions": 768,
        
        "indexType": "ivfflat",
        
        "similarity": "cosine"
        
      }
      
    },
    
    "mcp-server": {
    
      "enabled": false,
      
      "name": "MCP 服務器",
      
      "description": "Model Context Protocol 工具服務",
      
      "settings": {
      
        "transport": "stdio",
        
        "port": 3001,
        
        "authToken": "",
        
        "allowedOrigins": ["*"],
        
        "tools": {
        
          "search": true,
          
          "readDoc": true,
          
          "writeDoc": false,
          
          "summarize": true,
          
          "generate": true
          
        }
        
      }
      
    },
    
    "sync-engine": {
    
      "enabled": true,
      
      "name": "同步引擎",
      
      "description": "CRDT 實時協作同步",
      
      "settings": {
      
        "mode": "local-first",
        
        "webrtc": true,
        
        "websocket": false,
        
        "encryption": true
        
      }
      
    },
    
    "ai-assistant": {
    
      "enabled": true,
      
      "name": "AI 助手",
      
      "description": "智能寫作輔助和文檔分析",
      
      "settings": {
      
        "autoComplete": true,
        
        "smartSearch": true,
        
        "docSummary": true,
        
        "translation": true
        
      }
      
    }
    
  }
  
}

EOF


    
    echo -e "${GREEN}✓${NC} 模組配置創建: $CONFIG_FILE"
    

    
    # 創建啟動腳本
    
    cat > "$AFFINE_HOME/start.sh" << EOF
    
#!/bin/bash

# AFFiNE 快速啟動腳本



echo "🚀 啟動 AFFiNE Modular..."



# 檢查 PostgreSQL

if ! pgrep -x "postgres" > /dev/null; then

    echo "🐘 啟動 PostgreSQL..."
    
    brew services start postgresql@15
    
    sleep 2
    
fi



# 檢查 Ollama

if ! pgrep -x "ollama" > /dev/null; then

    echo "🧠 啟動 Ollama..."
    
    brew services start ollama
    
    sleep 2
    
fi



# 進入項目目錄

cd "$(pwd)"



# 啟動開發服務器

echo "🌐 啟動 AFFiNE 桌面端..."

yarn workspace @affine/electron dev

EOF



    chmod +x "$AFFINE_HOME/start.sh"
    
    echo -e "${GREEN}✓${NC} 啟動腳本創建: $AFFINE_HOME/start.sh"
    
}



# ============================================

# 步驟 6: 安裝依賴和構建

# ============================================

build_project() {

    echo ""
    
    echo -e "${BLUE}[6/6]${NC} 安裝依賴和構建項目..."
    

    
    # 安裝依賴
    
    echo -e "${YELLOW}!${NC} 安裝 Node 依賴..."
    
    yarn install
    

    
    # 構建 native
    
    echo -e "${YELLOW}!${NC} 構建 Rust Native 模組..."
    
    yarn workspace @affine/native build
    

    
    # 構建核心
    
    echo -e "${YELLOW}!${NC} 構建核心包..."
    
    yarn build
    

    
    echo -e "${GREEN}✓${NC} 項目構建完成"
    
}



# ============================================

# 主函數

# ============================================

main() {

    echo "開始設置 AFFiNE Modular Edition..."
    
    echo ""
    

    
    check_environment
    
    cleanup_repository
    
    setup_database
    
    setup_ollama
    
    setup_modules
    
    build_project
    

    
    echo ""
    
    echo "╔══════════════════════════════════════════════════════════╗"
    
    echo "║                  ✅ 設置完成！                           ║"
    
    echo "╚══════════════════════════════════════════════════════════╝"
    
    echo ""
    
    echo "📂 配置位置: $AFFINE_HOME/modules.json"
    
    echo "🚀 啟動命令: bash $AFFINE_HOME/start.sh"
    
    echo ""
    
    echo "📝 可用模組:"
    
    echo "   • 本地 LLM (llama3.2) - 已啟用"
    
    echo "   • 向量存儲 (pgvector)  - 已啟用"
    
    echo "   • MCP 服務器           - 默認關閉"
    
    echo "   • AI 助手              - 已啟用"
    
    echo ""
    
    echo "⚙️  編輯 ~/.affine/modules.json 調整配置"
    
    echo ""
    
}



# 執行主函數

main "$@"




































































































































































































































































































