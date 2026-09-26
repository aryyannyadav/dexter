import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createDexterBridge, type DexterBridge } from "../services/dexterBridge";
import type { DexterHubEvent, DexterHubViewModel } from "../types/dexterEvents";
import { MockDexterBridge } from "../services/mockDexterBridge";
import { defaultViewModel, reduceHubEvent } from "../state/dexterState";
import {
  mergeDemoHealthChecks,
  parseDemoHealthWireChecks,
  type DemoHealthCheck,
} from "../state/demoHealth";
import { resetHubDemoPresentationState } from "../state/hubDemoReset";
import {
  hubAmbientIdleSubtitle,
  hubAmbientIdleTitle,
  timeAwareIdleGreetingForSession,
} from "../state/hubAmbientSession";
import {
  applyHubMenuAction,
  applyHubPermissionAllow,
  applyHubPermissionDeny,
  applyHubRetry,
  type HubMenuAction,
} from "../state/hubLocalInteractions";

const HUB_MUTE_KEY = "dexter-hub-muted";
const SUCCESS_HOLD_BEFORE_IDLE_MS = 5200;

function applyOptionalSessionTimeGreeting(viewModel: DexterHubViewModel): DexterHubViewModel {
  if (viewModel.state !== "idle") return viewModel;
  const sessionGreeting = timeAwareIdleGreetingForSession();
  if (!sessionGreeting) return viewModel;
  return {
    ...viewModel,
    title: sessionGreeting,
    subtitle: hubAmbientIdleSubtitle,
  };
}

function shouldHoldSuccessBeforeIdle(previous: DexterHubViewModel, next: DexterHubViewModel): boolean {
  return (
    previous.state === "success" &&
    previous.verificationOutcome === "verified" &&
    previous.showSuccessCheck &&
    next.state === "idle"
  );
}

export function useDexterHub() {
  const bridge = useMemo<DexterBridge>(() => createDexterBridge(), []);
  const [viewModel, setViewModel] = useState(defaultViewModel);
  const pendingIdleViewModelRef = useRef<DexterHubViewModel | null>(null);
  const successHoldTimerRef = useRef<number | null>(null);
  const [isMuted, setIsMuted] = useState(() => {
    if (typeof window === "undefined") return false;
    return window.localStorage.getItem(HUB_MUTE_KEY) === "true";
  });
  const [macDemoHealthChecks, setMacDemoHealthChecks] = useState<DemoHealthCheck[]>([]);

  const mockBridge = bridge instanceof MockDexterBridge ? bridge : null;
  const usesMockBridge = mockBridge !== null;

  const demoHealthChecks = useMemo(
    () => mergeDemoHealthChecks(viewModel.connectionState, usesMockBridge, macDemoHealthChecks),
    [viewModel.connectionState, usesMockBridge, macDemoHealthChecks],
  );

  const ambientViewModel = useMemo(
    (): DexterHubViewModel => ({
      ...viewModel,
      ambientFocusMode: viewModel.ambientFocusMode || isMuted,
    }),
    [viewModel, isMuted],
  );

  const applyHubEvent = useCallback((event: DexterHubEvent) => {
    if (event.type === "demoHealth") {
      setMacDemoHealthChecks(parseDemoHealthWireChecks(event.checks));
      return;
    }

    setViewModel((previous) => {
      const next = reduceHubEvent(previous, event);

      if (shouldHoldSuccessBeforeIdle(previous, next)) {
        pendingIdleViewModelRef.current = {
          ...next,
          title: hubAmbientIdleTitle,
          subtitle: hubAmbientIdleSubtitle,
        };
        if (successHoldTimerRef.current !== null) {
          window.clearTimeout(successHoldTimerRef.current);
        }
        successHoldTimerRef.current = window.setTimeout(() => {
          successHoldTimerRef.current = null;
          const pendingIdle = pendingIdleViewModelRef.current;
          pendingIdleViewModelRef.current = null;
          if (!pendingIdle) return;
          setViewModel((current) =>
            current.state === "success" ? applyOptionalSessionTimeGreeting(pendingIdle) : current,
          );
        }, SUCCESS_HOLD_BEFORE_IDLE_MS);
        return previous;
      }

      if (event.type === "connection" && event.connectionState === "connected") {
        return applyOptionalSessionTimeGreeting(next);
      }

      if (event.type === "state" && event.state === "idle") {
        return applyOptionalSessionTimeGreeting({
          ...next,
          title: hubAmbientIdleTitle,
          subtitle: hubAmbientIdleSubtitle,
        });
      }

      return next;
    });
  }, []);

  useEffect(() => {
    const unsubscribe = bridge.subscribe(applyHubEvent);
    void bridge.connect();

    return () => {
      unsubscribe();
      bridge.disconnect();
      if (successHoldTimerRef.current !== null) {
        window.clearTimeout(successHoldTimerRef.current);
      }
    };
  }, [bridge, applyHubEvent]);

  useEffect(() => {
    if (viewModel.memoryPhase === "none") return;

    const memoryMomentResetTimer = window.setTimeout(() => {
      setViewModel((previous) => ({
        ...defaultViewModel,
        connectionState: previous.connectionState,
        applicationName: previous.applicationName,
        watchingApplicationName: previous.watchingApplicationName,
        projectContextLabel: previous.projectContextLabel,
        projectContextName: previous.projectContextName,
        ambientFocusMode: previous.ambientFocusMode,
      }));
    }, 4200);

    return () => window.clearTimeout(memoryMomentResetTimer);
  }, [viewModel.memoryPhase, viewModel.title, viewModel.subtitle]);

  const toggleMute = useCallback(() => {
    setIsMuted((previousMuted) => {
      const nextMuted = !previousMuted;
      window.localStorage.setItem(HUB_MUTE_KEY, String(nextMuted));
      return nextMuted;
    });
  }, []);

  const allow = useCallback(() => {
    bridge.sendCommand({ type: "allow" });
    if (!usesMockBridge) {
      setViewModel((previous) => applyHubPermissionAllow(previous, usesMockBridge));
    }
  }, [bridge, usesMockBridge]);

  const deny = useCallback(() => {
    bridge.sendCommand({ type: "deny" });
    if (!usesMockBridge) {
      setViewModel((previous) => applyHubPermissionDeny(previous));
    }
  }, [bridge, usesMockBridge]);

  const retry = useCallback(() => {
    if (usesMockBridge) {
      bridge.sendCommand({ type: "retry" });
      return;
    }
    setViewModel((previous) => applyHubRetry(previous, usesMockBridge));
    void bridge.reconnect();
  }, [bridge, usesMockBridge]);

  const reconnect = useCallback(() => {
    void bridge.reconnect();
  }, [bridge]);

  const refreshDemoHealth = useCallback(() => {
    bridge.sendCommand({ type: "requestDemoHealth" });
  }, [bridge]);

  const resetDemo = useCallback(() => {
    if (successHoldTimerRef.current !== null) {
      window.clearTimeout(successHoldTimerRef.current);
      successHoldTimerRef.current = null;
    }
    pendingIdleViewModelRef.current = null;
    mockBridge?.resetDemoPresentation();
    setViewModel((previous) => {
      if (previous.connectionState === "disconnected") {
        void bridge.reconnect();
      }
      return resetHubDemoPresentationState(previous);
    });
    refreshDemoHealth();
  }, [bridge, mockBridge, refreshDemoHealth]);

  const setTeachingDepth = useCallback(
    (depth: (typeof defaultViewModel)["teachingDepthSelection"]) => {
      setViewModel((previous) => ({ ...previous, teachingDepthSelection: depth }));
      bridge.sendCommand({ type: "teachingStyle", style: depth });
    },
    [bridge],
  );

  const viewMemoryRecord = useCallback(
    (memoryRecordId: string) => {
      bridge.sendCommand({ type: "memoryAction", action: "view", memoryRecordId });
    },
    [bridge],
  );

  const forgetMemoryRecord = useCallback(
    (memoryRecordId: string) => {
      bridge.sendCommand({ type: "memoryAction", action: "forget", memoryRecordId });
      setViewModel((previous) => ({
        ...previous,
        memoryPhase: "none",
        memoryRecordId: null,
        memoryActionsSupported: false,
        title: hubAmbientIdleTitle,
        subtitle: hubAmbientIdleSubtitle,
        state: "idle",
      }));
    },
    [bridge],
  );

  const acceptWorkflowRoutine = useCallback(() => {
    setViewModel((previous) => {
      bridge.sendCommand({
        type: "workflowSuggestionResponse",
        response: "yes",
        catalogWorkflowIdentifier: previous.workflowCatalogIdentifier ?? undefined,
      });
      return previous;
    });
  }, [bridge]);

  const dismissWorkflowRoutine = useCallback(() => {
    bridge.sendCommand({ type: "workflowSuggestionResponse", response: "notNow" });
    setViewModel((previous) => ({
      ...previous,
      workflowSuggestionPhase: "none",
      workflowRoutineName: null,
      workflowTrustPreview: null,
      workflowRoutineRunSupported: false,
      workflowCatalogIdentifier: null,
      state: "idle",
      title: hubAmbientIdleTitle,
      subtitle: hubAmbientIdleSubtitle,
    }));
  }, [bridge]);

  const runWorkflowRoutine = useCallback(() => {
    setViewModel((previous) => {
      if (!previous.workflowCatalogIdentifier) return previous;
      bridge.sendCommand({
        type: "workflowSuggestionResponse",
        response: "run",
        catalogWorkflowIdentifier: previous.workflowCatalogIdentifier,
      });
      return {
        ...previous,
        workflowSuggestionPhase: "none",
      };
    });
  }, [bridge]);

  const sendMenuAction = useCallback(
    (action: HubMenuAction) => {
      if (action === "mute") {
        toggleMute();
        return;
      }
      if (action === "reconnect") {
        reconnect();
        return;
      }
      if (action === "about") {
        return;
      }

      bridge.sendCommand({ type: "menu", action });
      setViewModel((previous) => applyHubMenuAction(previous, action));

      if (action === "teach" && mockBridge) {
        mockBridge.runTeachDemo();
      }
    },
    [bridge, mockBridge, reconnect, toggleMute],
  );

  return {
    bridge,
    mockBridge,
    usesMockBridge,
    isMuted,
    viewModel: ambientViewModel,
    demoHealthChecks,
    allow,
    deny,
    retry,
    reconnect,
    resetDemo,
    refreshDemoHealth,
    sendMenuAction,
    setTeachingDepth,
    viewMemoryRecord,
    forgetMemoryRecord,
    acceptWorkflowRoutine,
    dismissWorkflowRoutine,
    runWorkflowRoutine,
  };
}
