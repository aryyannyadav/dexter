import type { DexterHubViewModel } from "../types/dexterEvents";

export type HubMenuAction = "ask" | "teach" | "help" | "act" | "mute" | "reconnect" | "about";

const MAC_VOICE_HINT = "Speak on your Mac (Ctrl + Option). This tablet shows presence — not the microphone.";

export function applyHubMenuAction(previous: DexterHubViewModel, action: HubMenuAction): DexterHubViewModel {
  switch (action) {
    case "ask":
      return {
        ...previous,
        state: "listening",
        title: "I'm listening...",
        subtitle: MAC_VOICE_HINT,
        beat: "none",
        memoryPhase: "none",
        showSuccessCheck: false,
        permissionActionLabel: null,
        errorMessage: null,
      };
    case "teach":
      return {
        ...previous,
        state: "thinking",
        title: "What should I teach you?",
        subtitle: "Point at something on your Mac, then ask Dexter to teach it.",
        beat: "none",
        memoryPhase: "none",
        showSuccessCheck: false,
        permissionActionLabel: null,
        errorMessage: null,
      };
    case "help":
      return {
        ...previous,
        state: "aware",
        title: "Point at something on your Mac, press Dexter, and ask.",
        subtitle: MAC_VOICE_HINT,
        beat: "none",
        memoryPhase: "none",
        showSuccessCheck: false,
        permissionActionLabel: null,
        errorMessage: null,
      };
    case "act":
      return {
        ...previous,
        state: "aware",
        title: "What should I do?",
        subtitle: "Tell Dexter on your Mac what to act on.",
        beat: "none",
        memoryPhase: "none",
        showSuccessCheck: false,
        permissionActionLabel: null,
        errorMessage: null,
      };
    case "reconnect":
      return previous;
    case "about":
      return previous;
    case "mute":
      return previous;
    default:
      return previous;
  }
}

export function applyHubPermissionAllow(previous: DexterHubViewModel, usesMockBridge: boolean): DexterHubViewModel {
  if (usesMockBridge) {
    return previous;
  }
  return {
    ...previous,
    state: "aware",
    title: "Approve on your Mac",
    subtitle: "Tablet Allow only signals Dexter — confirm the action on your Mac to continue.",
    permissionActionLabel: null,
    showSuccessCheck: false,
  };
}

export function applyHubPermissionDeny(previous: DexterHubViewModel): DexterHubViewModel {
  return {
    ...previous,
    state: "aware",
    title: "okay.",
    subtitle: "I'm still here when you need me.",
    permissionActionLabel: null,
    showSuccessCheck: false,
    errorMessage: null,
  };
}

export function applyHubRetry(previous: DexterHubViewModel, usesMockBridge: boolean): DexterHubViewModel {
  if (usesMockBridge) {
    return previous;
  }
  return {
    ...previous,
    state: "idle",
    title: "Ready when you are.",
    subtitle: "your digital companion",
    errorMessage: null,
    showSuccessCheck: false,
    permissionActionLabel: null,
    beat: "none",
    memoryPhase: "none",
  };
}
