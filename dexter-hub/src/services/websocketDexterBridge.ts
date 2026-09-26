import type { DexterBridge, DexterBridgeListener } from "./dexterBridge";
import type { DexterCommand, DexterConnectionState, DexterHubEvent } from "../types/dexterEvents";

const MAX_RECONNECT_DELAY_MS = 15_000;

/**
 * Receives JSON events from the Dexter Mac Hub bridge (ws://<mac-ip>:8787/hub).
 */
export class WebSocketDexterBridge implements DexterBridge {
  private listeners = new Set<DexterBridgeListener>();
  private connectionState: DexterConnectionState = "disconnected";
  private socket: WebSocket | null = null;
  private reconnectTimer: number | null = null;
  private reconnectAttempt = 0;
  private intentionalDisconnect = false;
  private suppressAutoReconnect = false;

  constructor(private readonly websocketUrl: string) {}

  async connect(): Promise<void> {
    this.clearReconnectTimer();
    this.intentionalDisconnect = false;
    this.detachSocket();
    this.connectionState = "connecting";
    this.emit({ type: "connection", connectionState: "connecting" });

    try {
      await this.openSocket();
    } catch {
      this.connectionState = "disconnected";
      this.emit({ type: "connection", connectionState: "disconnected" });
      this.scheduleReconnect();
      throw new Error("WebSocket connection failed");
    }
  }

  async reconnect(): Promise<void> {
    this.clearReconnectTimer();
    this.intentionalDisconnect = false;
    this.reconnectAttempt = 0;
    this.suppressAutoReconnect = true;
    this.detachSocket();
    this.connectionState = "connecting";
    this.emit({ type: "connection", connectionState: "connecting" });

    try {
      await this.openSocket();
      this.suppressAutoReconnect = false;
    } catch {
      this.suppressAutoReconnect = false;
      this.connectionState = "disconnected";
      this.emit({ type: "connection", connectionState: "disconnected" });
    }
  }

  private openSocket(): Promise<void> {
    return new Promise((resolve, reject) => {
      let settled = false;

      try {
        this.socket = new WebSocket(this.websocketUrl);
      } catch (error) {
        this.connectionState = "disconnected";
        this.emit({ type: "connection", connectionState: "disconnected" });
        reject(error);
        return;
      }

      this.socket.onopen = () => {
        this.reconnectAttempt = 0;
        this.connectionState = "connected";
        this.emit({ type: "connection", connectionState: "connected" });
        if (!settled) {
          settled = true;
          resolve();
        }
      };

      this.socket.onmessage = (messageEvent) => {
        try {
          const parsed = JSON.parse(String(messageEvent.data)) as DexterHubEvent;
          this.emit(parsed);
        } catch {
          // Ignore malformed payloads — Mac bridge should send valid JSON only.
        }
      };

      this.socket.onerror = () => {
        if (this.connectionState !== "connected") {
          this.connectionState = "disconnected";
          this.emit({ type: "connection", connectionState: "disconnected" });
          if (!settled) {
            settled = true;
            reject(new Error("WebSocket connection failed"));
          }
        }
      };

      this.socket.onclose = () => {
        this.connectionState = "disconnected";
        this.emit({ type: "connection", connectionState: "disconnected" });
        this.socket = null;
        if (!settled) {
          settled = true;
          reject(new Error("WebSocket closed before open"));
        }
        if (!this.suppressAutoReconnect) {
          this.scheduleReconnect();
        }
      };
    });
  }

  disconnect(): void {
    this.intentionalDisconnect = true;
    this.clearReconnectTimer();
    this.detachSocket();
    this.connectionState = "disconnected";
    this.emit({ type: "connection", connectionState: "disconnected" });
  }

  sendCommand(command: DexterCommand): void {
    if (command.type === "reconnect") {
      void this.reconnect();
      return;
    }

    if (command.type === "requestDemoHealth") {
      if (this.socket?.readyState !== WebSocket.OPEN) {
        return;
      }
      this.socket.send(JSON.stringify({ type: "requestDemoHealth" }));
      return;
    }

    if (command.type === "teachingStyle") {
      if (this.socket?.readyState !== WebSocket.OPEN) {
        return;
      }
      this.socket.send(JSON.stringify({ type: "teachingStyle", style: command.style }));
      return;
    }

    if (command.type === "memoryAction") {
      if (this.socket?.readyState !== WebSocket.OPEN) {
        return;
      }
      this.socket.send(
        JSON.stringify({
          type: "memoryAction",
          action: command.action,
          memoryRecordId: command.memoryRecordId,
        }),
      );
      return;
    }

    if (command.type === "workflowSuggestionResponse") {
      if (this.socket?.readyState !== WebSocket.OPEN) {
        return;
      }
      this.socket.send(
        JSON.stringify({
          type: "workflowSuggestionResponse",
          response: command.response,
          catalogWorkflowIdentifier: command.catalogWorkflowIdentifier,
        }),
      );
      return;
    }

    if (this.socket?.readyState !== WebSocket.OPEN) {
      return;
    }
    this.socket.send(JSON.stringify({ type: "command", command }));
  }

  subscribe(listener: DexterBridgeListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  getConnectionState(): DexterConnectionState {
    return this.connectionState;
  }

  private detachSocket(): void {
    if (!this.socket) {
      return;
    }
    const activeSocket = this.socket;
    this.socket = null;
    activeSocket.onopen = null;
    activeSocket.onmessage = null;
    activeSocket.onerror = null;
    activeSocket.onclose = null;
    activeSocket.close();
  }

  private scheduleReconnect(): void {
    if (this.intentionalDisconnect) return;
    this.clearReconnectTimer();
    const delay = Math.min(1000 * 2 ** this.reconnectAttempt, MAX_RECONNECT_DELAY_MS);
    this.reconnectAttempt += 1;
    this.reconnectTimer = window.setTimeout(() => {
      void this.connect().catch(() => {
        // connect() schedules the next attempt
      });
    }, delay);
  }

  private clearReconnectTimer(): void {
    if (this.reconnectTimer !== null) {
      window.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  private emit(event: DexterHubEvent): void {
    for (const listener of this.listeners) {
      listener(event);
    }
  }
}
