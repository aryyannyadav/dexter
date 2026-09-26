import type { DexterBridge, DexterBridgeListener } from "./dexterBridge";
import type { DexterCommand, DexterConnectionState, DexterHubEvent, DexterState } from "../types/dexterEvents";

/** Internal identifier — mock sequences are not real Dexter verification. */
export const MOCK_CORE_DEMO_SEQUENCE_ID = "MOCK_CORE_DEMO";

const coreMockDemoSequence: DexterHubEvent[] = [
  {
    type: "state",
    state: "idle",
    title: "hey, I'm here.",
    subtitle: "your digital companion",
  },
  {
    type: "context",
    application: "VS Code",
    title: "I see what you're working on.",
    subtitle: "VS Code",
  },
  {
    type: "state",
    state: "listening",
    title: "I'm listening...",
    subtitle: "Tell me what you need.",
  },
  {
    type: "state",
    state: "thinking",
    title: "thinking...",
    subtitle: "Understanding what you're looking at",
  },
  {
    type: "permission",
    title: "Want me to do that?",
    subtitle: "Opening Telegram",
    actionLabel: "Opening Telegram",
  },
  {
    type: "state",
    state: "acting",
    title: "on it.",
    subtitle: "Opening Telegram",
  },
  {
    type: "state",
    state: "verifying",
    title: "checking...",
    subtitle: "Making sure it worked.",
  },
  {
    type: "state",
    state: "success",
    title: "Done.",
    subtitle: "Telegram is open.",
    verificationOutcome: "verified",
  },
];

const teachSequence: DexterHubEvent[] = [
  {
    type: "teaching",
    phase: "coaching",
    title: "let's learn this.",
    subtitle: "Export settings row",
    teachingStyle: "STANDARD",
  },
  {
    type: "teaching",
    phase: "explaining",
    title: "here's what's happening.",
    subtitle: "Click Settings",
    stepIndex: 1,
    stepSummary: "Click Settings",
    stepsPreview: [
      { index: 1, label: "Click Settings" },
      { index: 2, label: "Open Privacy" },
      { index: 3, label: "Enable screen recording" },
    ],
  },
  {
    type: "teaching",
    phase: "yourTurn",
    title: "your turn.",
    subtitle: "Click Settings",
    stepIndex: 1,
    stepSummary: "Click Settings",
  },
  {
    type: "teaching",
    phase: "affirmation",
    title: "that's it.",
    subtitle: "Nice — ready for the next bit.",
    stepIndex: 1,
  },
];

const memorySequence: DexterHubEvent[] = [
  {
    type: "projectContext",
    label: "WORKING ON",
    projectName: "Eventra",
  },
  {
    type: "memory",
    phase: "remembering",
    title: "I'll remember that.",
    subtitle: "Eventra uses MongoDB.",
    memoryRecordId: "00000000-0000-0000-0000-000000000001",
    memoryActionsSupported: true,
  },
  {
    type: "memory",
    phase: "recalled",
    title: "I remembered.",
    subtitle: "MongoDB.",
    preferenceReflection: "Keeping this concise, like you prefer.",
  },
];

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

export class MockDexterBridge implements DexterBridge {
  private listeners = new Set<DexterBridgeListener>();
  private connectionState: DexterConnectionState = "disconnected";
  private sequenceTimer: number | null = null;
  private sequenceRunId = 0;
  private forcedDisconnected = false;

  async connect(): Promise<void> {
    this.connectionState = "connecting";
    this.emit({ type: "connection", connectionState: "connecting" });
    await delay(400);
    if (this.forcedDisconnected) {
      this.connectionState = "disconnected";
      this.emit({ type: "connection", connectionState: "disconnected" });
      return;
    }
    this.connectionState = "connected";
    this.emit({ type: "connection", connectionState: "connected" });
    this.emit({
      type: "state",
      state: "idle",
      title: "hey, I'm here.",
      subtitle: "your digital companion",
    });
  }

  disconnect(): void {
    if (this.sequenceTimer !== null) {
      window.clearTimeout(this.sequenceTimer);
      this.sequenceTimer = null;
    }
    this.connectionState = "disconnected";
    this.emit({ type: "connection", connectionState: "disconnected" });
  }

  async reconnect(): Promise<void> {
    this.forcedDisconnected = false;
    await this.connect();
  }

  resetDemoPresentation(): void {
    if (this.sequenceTimer !== null) {
      window.clearTimeout(this.sequenceTimer);
      this.sequenceTimer = null;
    }
    this.sequenceRunId += 1;
    this.forcedDisconnected = false;
    if (this.connectionState !== "connected") {
      void this.connect();
      return;
    }
    this.emit({
      type: "state",
      state: "idle",
      title: "hey, I'm here.",
      subtitle: "your digital companion",
    });
  }

  private emitDemoHealth(): void {
    this.emit({
      type: "demoHealth",
      checks: [
        { id: "OPENCLAW", status: "fail" },
        { id: "SCREEN", status: "fail" },
        { id: "MICROPHONE", status: "fail" },
        { id: "STT", status: "fail" },
        { id: "TTS", status: "fail" },
        { id: "VERIFICATION", status: "fail" },
      ],
    });
  }

  sendCommand(command: DexterCommand): void {
    switch (command.type) {
      case "reconnect":
        void this.reconnect();
        return;
      case "requestDemoHealth":
        this.emitDemoHealth();
        return;
      case "allow":
        this.emit({
          type: "state",
          state: "acting",
          title: "on it.",
          subtitle: "Opening Telegram",
        });
        void this.runActingToSuccess();
        break;
      case "deny":
        this.emit({
          type: "state",
          state: "aware",
          title: "okay.",
          subtitle: "I'm still here when you need me.",
        });
        break;
      case "retry":
        void this.reconnect();
        break;
      case "menu":
        if (command.action === "reconnect") {
          void this.reconnect();
        }
        break;
      default:
        break;
    }
  }

  subscribe(listener: DexterBridgeListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  getConnectionState(): DexterConnectionState {
    return this.connectionState;
  }

  emitDemoEvent(event: DexterHubEvent): void {
    this.emit(event);
  }

  setDisconnected(disconnected: boolean): void {
    this.forcedDisconnected = disconnected;
    if (disconnected) {
      this.disconnect();
    } else {
      void this.connect();
    }
  }

  runCoreDemo(): void {
    void this.playSequence(coreMockDemoSequence, 2200, MOCK_CORE_DEMO_SEQUENCE_ID);
  }

  /** @deprecated Use runCoreDemo — hackathon mock fallback only */
  runDemoSequence(): void {
    this.runCoreDemo();
  }

  runTeachDemo(): void {
    void this.playSequence(teachSequence, 2400);
  }

  runMemoryDemo(): void {
    void this.playSequence(memorySequence, 2800);
  }

  triggerState(state: DexterState): void {
    const presets: Partial<Record<DexterState, DexterHubEvent>> = {
      idle: {
        type: "state",
        state: "idle",
        title: "hey, I'm here.",
        subtitle: "your digital companion",
      },
      aware: {
        type: "context",
        application: "VS Code",
        title: "I see what you're working on.",
        subtitle: "VS Code",
      },
      listening: {
        type: "state",
        state: "listening",
        title: "I'm listening...",
        subtitle: "Tell me what you need.",
      },
      thinking: {
        type: "state",
        state: "thinking",
        title: "thinking...",
        subtitle: "Understanding what you're looking at",
      },
      acting: {
        type: "state",
        state: "acting",
        title: "on it.",
        subtitle: "Opening Telegram",
      },
      verifying: {
        type: "state",
        state: "verifying",
        title: "checking...",
        subtitle: "Making sure it worked.",
      },
      success: {
        type: "state",
        state: "success",
        title: "Done.",
        subtitle: "Telegram is open.",
        verificationOutcome: "verified",
      },
      permission: {
        type: "permission",
        title: "Want me to do that?",
        subtitle: "Opening Telegram",
        actionLabel: "Opening Telegram",
      },
      error: {
        type: "state",
        state: "error",
        title: "I couldn't finish that.",
        subtitle: "Telegram didn't open in time.",
      },
      disconnected: {
        type: "connection",
        connectionState: "disconnected",
      },
    };
    const event = presets[state];
    if (event) this.emit(event);
  }

  private async runActingToSuccess(): Promise<void> {
    await delay(1200);
    this.emit({
      type: "state",
      state: "verifying",
      title: "checking...",
      subtitle: "Making sure it worked.",
    });
    await delay(1400);
    this.emit({
      type: "state",
      state: "success",
      title: "Done.",
      subtitle: "Telegram is open.",
      verificationOutcome: "verified",
    });
  }

  private async playSequence(
    events: DexterHubEvent[],
    stepMs: number,
    sequenceIdentifier?: string,
  ): Promise<void> {
    const runId = ++this.sequenceRunId;
    if (this.sequenceTimer !== null) {
      window.clearTimeout(this.sequenceTimer);
      this.sequenceTimer = null;
    }
    if (sequenceIdentifier) {
      console.info(`[DexterHub][MOCK] sequence=${sequenceIdentifier}`);
    }
    for (let index = 0; index < events.length; index += 1) {
      if (runId !== this.sequenceRunId) {
        return;
      }
      const event = events[index];
      this.emit(event);
      if (index < events.length - 1) {
        await delay(stepMs);
      }
    }
  }

  private emit(event: DexterHubEvent): void {
    for (const listener of this.listeners) {
      listener(event);
    }
  }
}
