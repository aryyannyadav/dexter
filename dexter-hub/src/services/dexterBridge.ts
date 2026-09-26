import type { DexterCommand, DexterConnectionState, DexterHubEvent } from "../types/dexterEvents";
import { MockDexterBridge } from "./mockDexterBridge";
import { WebSocketDexterBridge } from "./websocketDexterBridge";

export type DexterBridgeListener = (event: DexterHubEvent) => void;

export interface DexterBridge {
  connect(): Promise<void>;
  disconnect(): void;
  reconnect(): Promise<void>;
  sendCommand(command: DexterCommand): void;
  subscribe(listener: DexterBridgeListener): () => void;
  getConnectionState(): DexterConnectionState;
}

export type DexterBridgeFactoryOptions = {
  websocketUrl?: string;
  useMock?: boolean;
};

export function defaultDexterHubWebSocketURL(): string {
  if (import.meta.env.VITE_DEXTER_WS_URL) {
    return import.meta.env.VITE_DEXTER_WS_URL;
  }
  if (typeof window === "undefined") {
    return "ws://localhost:8787/hub";
  }
  const hostname = window.location.hostname || "localhost";
  return `ws://${hostname}:8787/hub`;
}

export function createDexterBridge(options: DexterBridgeFactoryOptions = {}): DexterBridge {
  const useMock = options.useMock ?? import.meta.env.VITE_DEXTER_USE_MOCK === "true";

  if (useMock) {
    return new MockDexterBridge();
  }

  const url = options.websocketUrl ?? defaultDexterHubWebSocketURL();
  return new WebSocketDexterBridge(url);
}
