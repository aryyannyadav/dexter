/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_DEXTER_USE_MOCK?: string;
  readonly VITE_DEXTER_WS_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
