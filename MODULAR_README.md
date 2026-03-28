# 🚀 AFFiNE 魔改版本 - 本地 LLM + MCP + 插拔式模組



> 一個專為 macOS + iOS 設計的全功能知識庫，整合本地 LLM、向量數據庫、MCP 工具



## ✨ 功能特性



| 模組 | 狀態 | 說明 |

|------|------|------|

| 🔥 本地 LLM | 內建 | Ollama 整合，支援 llama3.2/qwen2.5/mistral |

| 📊 向量存儲 | 內建 | pgvector 語義搜索，768維嵌入 |

| 🔌 MCP 服務器 | 內建 | Model Context Protocol，Claude/Cursor 接入 |

| 🌐 CRDT 同步 | 內建 | Yjs 實時協作 |

| 🧩 插拔式架構 | 核心 | 每個功能獨立開關 + 參數調整 |



## 📁 文件結構



```

AFFiNE/

├── .github/workflows/build-macos-ios.yml  # 自動編譯打包

├── modular-setup.sh                        # 一鍵環境設置

├── start-affine.sh                         # 快速啟動

├── packages/

│   ├── backend/server/src/plugins/

│   │   ├── local-llm/                      # LLM 模組

│   │   ├── vector-store/                   # 向量存儲

│   │   └── mcp-server/                     # MCP 工具

│   └── frontend/core/src/modules/ai/       # AI 前端組件

└── MODULAR_CONFIG.json                     # 模組配置

```



## 🚀 快速開始



### 方法 1：下載即用版本（推薦）



1. 進入 [Actions](https://github.com/ivankayiu/AFFiNE/actions)

2. 選擇最新成功的 `Build macOS & iOS` 工作流

3. 下載 `affine-macos-universal` 或 `affine-ios` 成品

4. 雙擊即可運行！



### 方法 2：本地編譯



```bash

# 1. 克隆魔改分支

git clone -b modular-llm-mcp https://github.com/ivankayiu/AFFiNE.git

cd AFFiNE



# 2. 執行魔改腳本

chmod +x modular-setup.sh

./modular-setup.sh



# 3. 啟動

./start-affine.sh

```



## ⚙️ 模組配置



配置文件位置：`~/.affine/modules.json`



```json

{

  "modules": {

    "local-llm": {

      "enabled": true,

      "settings": {

        "provider": "ollama",

        "model": "llama3.2",

        "useGPU": true

      }

    },

    "mcp-server": {

      "enabled": false,

      "settings": {

        "transport": "stdio",

        "tools": { "search": true, "writeDoc": false }

      }

    }

  }

}

```



## 🔌 MCP 接入



### Cursor

```json

// ~/.cursor/mcp.json

{

  "mcpServers": {

    "affine": {

      "command": "/Applications/AFFiNE.app/Contents/Resources/mcp-server.js"

    }

  }

}

```



### Claude Desktop

```json

// ~/Library/Application Support/Claude/claude_desktop_config.json

{

  "mcpServers": {

    "affine": {

      "command": "/Applications/AFFiNE.app/Contents/Resources/mcp-server.js"

    }

  }

}

```



## 📱 iOS 版本



- 支援 iPhone/iPad

- 與桌面端數據同步

- 完整離線功能



## 🔧 開發者指南



### 添加新模組



```typescript

// packages/backend/server/src/plugins/my-module/module.ts

export default class MyModule implements FeatureModule {

  config = {

    id: 'my-module',

    name: '我的模組',

    enabled: true,

    version: '1.0.0'

  };



  async initialize() { /* ... */ }

  registerRoutes(router) { /* ... */ }

}

```



## 📝 技術棧



- **前端**: TypeScript, React, Vite, BlockSuite

- **後端**: NestJS, GraphQL, PostgreSQL

- **原生**: Rust (napi-rs), Swift (iOS)

- **AI**: Ollama, pgvector, MCP



## 📄 許可證



MIT License - 基於 [toeverything/AFFiNE](https://github.com/toeverything/AFFiNE)



---



**Made with ❤️ by ivankayiu**
