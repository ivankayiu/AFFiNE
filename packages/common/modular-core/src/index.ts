/**

 * AFFiNE Modular Core - 插拔式模組系統
 
 * 設計理念：功能獨立、動態載入、熱插拔、配置驅動
 
 */
 


import { EventEmitter } from 'events';

import { Router } from 'express';



// ============ 類型定義 ============



export interface ModuleConfig {

  id: string;
  
  name: string;
  
  enabled: boolean;
  
  version: string;
  
  settings: Record<string, any>;
  
  dependencies?: string[];
  
  description?: string;
  
  icon?: string;
  
}



export interface SettingsSchemaField {

  type: 'string' | 'number' | 'boolean' | 'select' | 'slider' | 'array' | 'object';
  
  label: string;
  
  description?: string;
  
  default?: any;
  
  placeholder?: string;
  
  options?: string[] | { value: string; label: string }[];
  
  min?: number;
  
  max?: number;
  
  step?: number;
  
  required?: boolean;
  
}



export interface SettingsSchema {

  [key: string]: SettingsSchemaField;
  
}



export interface HandlerRegistry {

  register: (event: string, handler: Function) => void;
  
  unregister: (event: string, handler: Function) => void;
  
}



export interface FeatureModule {

  readonly config: ModuleConfig;
  

  
  // 生命週期
  
  initialize(): Promise<void>;
  
  destroy(): Promise<void>;
  

  
  // 配置
  
  updateSettings(settings: Partial<any>): Promise<void>;
  
  getSettingsSchema(): SettingsSchema;
  

  
  // API 註冊
  
  registerRoutes(router: Router): void;
  
  registerHandlers(handlers: HandlerRegistry): void;
  

  
  // 狀態
  
  getStatus(): ModuleStatus;
  
}



export interface ModuleStatus {

  state: 'initialized' | 'running' | 'error' | 'stopped';
  
  error?: string;
  
  lastStarted?: Date;
  
  lastStopped?: Date;
  
}



export interface ModularOptions {

  configPath: string;
  
  modulesDir: string;
  
  autoLoad?: boolean;
  
  hotReload?: boolean;
  
}



// ============ 配置存儲 ============



class ConfigStore {

  private config: Map<string, ModuleConfig> = new Map();
  
  private configPath: string;
  

  
  constructor(configPath: string) {
  
    this.configPath = configPath;
    
    this.loadFromDisk();
    
  }
  

  
  private loadFromDisk(): void {
  
    try {
    
      const fs = require('fs');
      
      const path = require('path');
      

      
      if (fs.existsSync(this.configPath)) {
      
        const data = fs.readFileSync(this.configPath, 'utf-8');
        
        const parsed = JSON.parse(data);
        

        
        for (const [id, config] of Object.entries(parsed.modules || {})) {
        
          this.config.set(id, config as ModuleConfig);
          
        }
        
      }
      
    } catch (error) {
    
      console.warn('[ConfigStore] Failed to load config:', error);
      
    }
    
  }
  

  
  private saveToDisk(): void {
  
    try {
    
      const fs = require('fs');
      
      const path = require('path');
      

      
      // 確保目錄存在
      
      const dir = path.dirname(this.configPath);
      
      if (!fs.existsSync(dir)) {
      
        fs.mkdirSync(dir, { recursive: true });
        
      }
      

      
      const data = {
      
        version: '1.0.0',
        
        lastUpdated: new Date().toISOString(),
        
        modules: Object.fromEntries(this.config)
        
      };
      

      
      fs.writeFileSync(this.configPath, JSON.stringify(data, null, 2));
      
    } catch (error) {
    
      console.error('[ConfigStore] Failed to save config:', error);
      
    }
    
  }
  

  
  load(moduleId: string): ModuleConfig | undefined {
  
    return this.config.get(moduleId);
    
  }
  

  
  get(moduleId: string): ModuleConfig | undefined {
  
    return this.config.get(moduleId);
    
  }
  

  
  update(moduleId: string, updates: Partial<ModuleConfig>): void {
  
    const existing = this.config.get(moduleId) || {} as ModuleConfig;
    
    this.config.set(moduleId, { ...existing, ...updates });
    
    this.saveToDisk();
    
  }
  

  
  getAll(): Map<string, ModuleConfig> {
  
    return new Map(this.config);
    
  }
  
}



// ============ 事件總線 ============



class EventBus extends EventEmitter {

  emit(event: string, ...args: any[]): boolean {
  
    console.log(`[EventBus] ${event}`, args);
    
    return super.emit(event, ...args);
    
  }
  
}



// ============ 模組管理器 ============



export class ModularManager {

  private modules = new Map<string, FeatureModule>();
  
  private configStore: ConfigStore;
  
  private eventBus: EventBus;
  
  private router: Router;
  
  private handlerRegistry: HandlerRegistry;
  

  
  constructor(private options: ModularOptions) {
  
    this.configStore = new ConfigStore(options.configPath);
    
    this.eventBus = new EventBus();
    
    this.router = Router();
    
    this.handlerRegistry = {
    
      register: (event, handler) => this.eventBus.on(event, handler),
      
      unregister: (event, handler) => this.eventBus.off(event, handler)
      
    };
    

    
    if (options.autoLoad) {
    
      this.autoLoadModules();
      
    }
    
  }
  

  
  // ============ 模組載入 ============
  

  
  async loadModule(modulePath: string): Promise<void> {
  
    try {
    
      // 動態導入模組
      
      const moduleClass = await import(modulePath);
      
      const ModuleConstructor = moduleClass.default || moduleClass;
      
      const instance: FeatureModule = new ModuleConstructor();
      

      
      const moduleId = instance.config.id;
      

      
      // 檢查是否已存在
      
      if (this.modules.has(moduleId)) {
      
        throw new Error(`Module ${moduleId} already loaded`);
        
      }
      

      
      // 檢查依賴
      
      if (instance.config.dependencies) {
      
        for (const dep of instance.config.dependencies) {
        
          if (!this.modules.has(dep)) {
          
            throw new Error(
            
              `Module ${moduleId} depends on ${dep} which is not loaded`
              
            );
            
          }
          

          
          // 檢查依賴是否啟用
          
          const depConfig = this.configStore.get(dep);
          
          if (depConfig && !depConfig.enabled) {
          
            throw new Error(
            
              `Module ${moduleId} depends on ${dep} which is disabled`
              
            );
            
          }
          
        }
        
      }
      

      
      // 載入配置
      
      const savedConfig = this.configStore.load(moduleId);
      
      if (savedConfig) {
      
        Object.assign(instance.config, savedConfig);
        
      }
      

      
      // 註冊模組
      
      this.modules.set(moduleId, instance);
      

      
      // 註冊路由
      
      instance.registerRoutes(this.router);
      
      instance.registerHandlers(this.handlerRegistry);
      

      
      // 如果配置為啟用，自動初始化
      
      if (instance.config.enabled !== false) {
      
        await this.initializeModule(moduleId);
        
      }
      

      
      this.eventBus.emit('module:loaded', moduleId);
      
      console.log(`[ModularManager] Module ${moduleId} loaded`);
      

      
    } catch (error) {
    
      console.error(`[ModularManager] Failed to load module:`, error);
      
      throw error;
      
    }
    
  }
  

  
  async unloadModule(moduleId: string): Promise<void> {
  
    const module = this.modules.get(moduleId);
    
    if (!module) {
    
      throw new Error(`Module ${moduleId} not found`);
      
    }
    

    
    // 檢查是否有其他模組依賴於此
    
    for (const [id, mod] of this.modules) {
    
      if (mod.config.dependencies?.includes(moduleId)) {
      
        throw new Error(
        
          `Cannot unload ${moduleId}: ${id} depends on it`
          
        );
        
      }
      
    }
    

    
    // 如果正在運行，先停止
    
    if (module.getStatus().state === 'running') {
    
      await this.stopModule(moduleId);
      
    }
    

    
    this.modules.delete(moduleId);
    
    this.eventBus.emit('module:unloaded', moduleId);
    
  }
  

  
  // ============ 模組生命週期 ============
  

  
  async initializeModule(moduleId: string): Promise<void> {
  
    const module = this.modules.get(moduleId);
    
    if (!module) {
    
      throw new Error(`Module ${moduleId} not found`);
      
    }
    

    
    try {
    
      await module.initialize();
      
      this.configStore.update(moduleId, { enabled: true });
      
      this.eventBus.emit('module:initialized', moduleId);
      
      console.log(`[ModularManager] Module ${moduleId} initialized`);
      
    } catch (error) {
    
      console.error(`[ModularManager] Failed to initialize ${moduleId}:`, error);
      
      throw error;
      
    }
    
  }
  

  
  async stopModule(moduleId: string): Promise<void> {
  
    const module = this.modules.get(moduleId);
    
    if (!module) {
    
      throw new Error(`Module ${moduleId} not found`);
      
    }
    

    
    try {
    
      await module.destroy();
      
      this.configStore.update(moduleId, { enabled: false });
      
      this.eventBus.emit('module:stopped', moduleId);
      
      console.log(`[ModularManager] Module ${moduleId} stopped`);
      
    } catch (error) {
    
      console.error(`[ModularManager] Failed to stop ${moduleId}:`, error);
      
      throw error;
      
    }
    
  }
  

  
  // ============ 熱插拔 ============
  

  
  async toggleModule(moduleId: string, enabled: boolean): Promise<void> {
  
    const module = this.modules.get(moduleId);
    
    if (!module) {
    
      throw new Error(`Module ${moduleId} not found`);
      
    }
    

    
    const currentState = module.getStatus().state;
    

    
    if (enabled && currentState !== 'running') {
    
      await this.initializeModule(moduleId);
      
    } else if (!enabled && currentState === 'running') {
    
      await this.stopModule(moduleId);
      
    }
    
  }
  

  
  // ============ 配置管理 ============
  

  
  async updateModuleSettings(
  
    moduleId: string, 
    
    settings: Record<string, any>
    
  ): Promise<void> {
  
    const module = this.modules.get(moduleId);
    
    if (!module) {
    
      throw new Error(`Module ${moduleId} not found`);
      
    }
    

    
    // 更新模組設置
    
    await module.updateSettings(settings);
    

    
    // 保存到配置存儲
    
    this.configStore.update(moduleId, { settings });
    

    
    this.eventBus.emit('module:settings-updated', { moduleId, settings });
    
  }
  

  
  // ============ 查詢 ============
  

  
  getModule(moduleId: string): FeatureModule | undefined {
  
    return this.modules.get(moduleId);
    
  }
  

  
  getAllModules(): Array<ModuleConfig & { active: boolean; status: ModuleStatus }> {
  
    return Array.from(this.modules.entries()).map(([id, module]) => ({
    
      ...module.config,
      
      active: module.getStatus().state === 'running',
      
      status: module.getStatus()
      
    }));
    
  }
  

  
  getRouter(): Router {
  
    return this.router;
    
  }
  

  
  // ============ 自動載入 ============
  

  
  private async autoLoadModules(): Promise<void> {
  
    try {
    
      const fs = require('fs');
      
      const path = require('path');
      

      
      if (!fs.existsSync(this.options.modulesDir)) {
      
        console.warn(`[ModularManager] Modules directory not found: ${this.options.modulesDir}`);
        
        return;
        
      }
      

      
      const entries = fs.readdirSync(this.options.modulesDir, { withFileTypes: true });
      

      
      for (const entry of entries) {
      
        if (entry.isDirectory()) {
        
          const modulePath = path.join(this.options.modulesDir, entry.name, 'module.ts');
          
          if (fs.existsSync(modulePath)) {
          
            try {
            
              await this.loadModule(modulePath);
              
            } catch (error) {
            
              console.error(`[ModularManager] Failed to auto-load ${entry.name}:`, error);
              
            }
            
          }
          
        }
        
      }
      
    } catch (error) {
    
      console.error('[ModularManager] Auto-load failed:', error);
      
    }
    
  }
  

  
  // ============ 熱重載（開發模式） ============
  

  
  enableHotReload(): void {
  
    if (!this.options.hotReload) return;
    

    
    try {
    
      const fs = require('fs');
      
      const path = require('path');
      

      
      fs.watch(this.options.modulesDir, { recursive: true }, (eventType, filename) => {
      
        if (filename?.endsWith('module.ts')) {
        
          console.log(`[ModularManager] Detected change in ${filename}, reloading...`);
          
          // 實現熱重載邏輯
          
        }
        
      });
      
    } catch (error) {
    
      console.warn('[ModularManager] Hot reload not available:', error);
      
    }
    
  }
  
}



// ============ 導出 ============



export { ConfigStore, EventBus };

export default ModularManager;














































































































































































































































































































































































