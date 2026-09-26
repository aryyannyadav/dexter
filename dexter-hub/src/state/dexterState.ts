import type {
  DexterHubBeat,
  DexterHubEvent,
  DexterHubInteraction,
  DexterHubJourneyStep,
  DexterHubTeachingPhase,
  DexterHubViewModel,
  DexterState,
} from "../types/dexterEvents";

export const defaultViewModel: DexterHubViewModel = {
  state: "idle",
  title: "hey, I'm here.",
  subtitle: "your digital companion",
  applicationName: null,
  connectionState: "connecting",
  permissionActionLabel: null,
  errorMessage: null,
  showSuccessCheck: false,
  interaction: "default",
  beat: "none",
  memoryPhase: "none",
  memoryRecordId: null,
  memoryActionsSupported: false,
  memoryPreferenceReflection: null,
  projectContextLabel: null,
  projectContextName: null,
  voiceVisualOnly: false,
  workflowSuggestionPhase: "none",
  workflowRoutineName: null,
  workflowTrustPreview: null,
  workflowRoutineRunSupported: false,
  workflowCatalogIdentifier: null,
  ambientFocusMode: false,
  watchingApplicationName: null,
  journeySteps: null,
  retrySupported: false,
  verificationOutcome: "none",
  teachingPhase: "none",
  teachingStyle: null,
  teachingStepIndex: null,
  teachingStepSummary: null,
  teachingStepsPreview: null,
  teachingDepthSelection: "normal",
};

export function timeAwareIdleGreeting(): string {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) return "good morning.";
  if (hour >= 12 && hour < 17) return "hey.";
  if (hour >= 17 && hour < 22) return "still working?";
  return "you're still here?";
}

export function stateCharacterAssetPath(state: DexterState, beat: DexterHubBeat, teachingPhase: DexterHubTeachingPhase): string {
  if (teachingPhase !== "none") {
    return "/characters/speaking.png";
  }
  if (beat === "answer") {
    return "/characters/speaking.png";
  }
  switch (state) {
    case "listening":
    case "permission":
      return "/characters/listening.png";
    case "speaking":
      return "/characters/speaking.png";
    case "thinking":
      return "/characters/thinking.png";
    case "acting":
    case "verifying":
      return "/characters/working.png";
    case "success":
      return "/characters/success.png";
    case "error":
      return "/characters/error.png";
    case "disconnected":
      return "/characters/sleeping.png";
    case "aware":
      return "/characters/speaking.png";
    case "idle":
    default:
      return "/characters/idle.png";
  }
}

export function characterAnimationClass(
  state: DexterState,
  beat: DexterHubBeat,
  teachingPhase: DexterHubTeachingPhase,
  memoryPhase: DexterHubViewModel["memoryPhase"] = "none",
): string {
  if (memoryPhase === "remembering") {
    return "dexter-anim dexter-anim--memory-attentive";
  }
  if (state === "speaking") {
    return "dexter-anim dexter-anim--speaking-visual";
  }
  if (state === "listening") {
    return "dexter-anim dexter-anim--listening";
  }
  if (teachingPhase !== "none") {
    return "dexter-anim dexter-anim--teaching";
  }
  if (beat === "understandingLook" || beat === "understandingGotIt" || beat === "targetUncertain") {
    return "dexter-anim dexter-anim--thinking";
  }
  if (beat === "actionCanDo" || beat === "actionWantMeTo") {
    return "dexter-anim dexter-anim--aware";
  }
  if (beat === "answer") {
    return "dexter-anim dexter-anim--aware";
  }
  return `dexter-anim dexter-anim--${state}`;
}

function resolveInteraction(
  incoming: DexterHubInteraction | undefined,
  previous: DexterHubInteraction,
): DexterHubInteraction {
  return incoming ?? previous;
}

function normalizeJourneySteps(incoming?: DexterHubJourneyStep[]): DexterHubViewModel["journeySteps"] {
  if (!incoming?.length) return null;
  return incoming.map((step) => ({
    label: step.label,
    status:
      step.status === "failed"
        ? "failed"
        : step.status === "active"
          ? "active"
          : step.status === "done"
            ? "done"
            : "pending",
  }));
}

function journeyFingerprint(steps: DexterHubViewModel["journeySteps"]): string {
  if (!steps?.length) return "";
  return steps.map((step) => `${step.label}:${step.status}`).join(",");
}

export function reduceHubEvent(
  previous: DexterHubViewModel,
  event: DexterHubEvent,
): DexterHubViewModel {
  switch (event.type) {
    case "demoHealth":
      return previous;

    case "connection":
      if (event.connectionState === "disconnected") {
        return {
          ...previous,
          state: "disconnected",
          connectionState: "disconnected",
          title: "I can't reach Dexter.",
          subtitle: "Make sure Dexter is running on your Mac.",
          showSuccessCheck: false,
          permissionActionLabel: null,
          errorMessage: null,
          interaction: "default",
          beat: "none",
          journeySteps: null,
          retrySupported: false,
          verificationOutcome: "none",
        };
      }
      return {
        ...previous,
        connectionState: event.connectionState,
        ...(event.connectionState === "connected" && previous.state === "disconnected"
          ? { ...defaultViewModel, applicationName: previous.applicationName }
          : {}),
      };

    case "ambient":
      return {
        ...previous,
        state: event.state,
        title: event.title,
        subtitle: event.subtitle ?? "",
        applicationName: event.application ?? previous.applicationName,
        interaction: resolveInteraction(event.interaction, previous.interaction),
        beat: event.beat,
        showSuccessCheck: false,
        permissionActionLabel: null,
        errorMessage: null,
      };

    case "context":
      if (
        previous.state === "idle" &&
        previous.beat === "none" &&
        previous.memoryPhase === "none" &&
        previous.teachingPhase === "none" &&
        previous.workflowSuggestionPhase === "none"
      ) {
        return {
          ...previous,
          applicationName: event.application ?? previous.applicationName,
          watchingApplicationName: event.application ?? previous.watchingApplicationName,
        };
      }
      return {
        ...previous,
        state: "aware",
        title: event.title,
        subtitle: event.subtitle ?? (event.application ?? ""),
        applicationName: event.application ?? previous.applicationName,
        interaction: resolveInteraction(event.interaction, previous.interaction),
        beat: "none",
        showSuccessCheck: false,
        permissionActionLabel: null,
        errorMessage: null,
      };

    case "permission":
      return {
        ...previous,
        state: "permission",
        title: event.title,
        subtitle: event.subtitle,
        permissionActionLabel: event.actionLabel,
        interaction: resolveInteraction(event.interaction, previous.interaction),
        beat: "none",
        showSuccessCheck: false,
        errorMessage: null,
        journeySteps: normalizeJourneySteps(event.journeySteps),
        retrySupported: false,
        verificationOutcome: "none",
      };

    case "memory":
      return {
        ...previous,
        state: "aware",
        title: event.title,
        subtitle: event.subtitle ?? "",
        memoryPhase: event.phase,
        memoryRecordId: event.memoryRecordId ?? null,
        memoryActionsSupported: event.memoryActionsSupported ?? false,
        memoryPreferenceReflection: event.preferenceReflection ?? null,
        applicationName: previous.applicationName,
        interaction: "default",
        beat: "none",
        showSuccessCheck: false,
        permissionActionLabel: null,
        errorMessage: null,
        teachingPhase: "none",
      };

    case "projectContext":
      return {
        ...previous,
        projectContextLabel: event.label,
        projectContextName: event.projectName,
      };

    case "watching":
      return {
        ...previous,
        applicationName: event.application,
        watchingApplicationName: event.application,
      };

    case "ambientFocus":
      return {
        ...previous,
        ambientFocusMode: event.focusMode,
      };

    case "workflowSuggestion":
      if (event.phase === "none") {
        return {
          ...previous,
          workflowSuggestionPhase: "none",
          workflowRoutineName: null,
          workflowTrustPreview: null,
          workflowRoutineRunSupported: false,
          workflowCatalogIdentifier: null,
        };
      }
      return {
        ...previous,
        state: "aware",
        title: event.title,
        subtitle: event.subtitle ?? "",
        workflowSuggestionPhase: event.phase,
        workflowRoutineName: event.routineDisplayName ?? previous.workflowRoutineName,
        workflowTrustPreview: event.trustPreview ?? previous.workflowTrustPreview,
        workflowRoutineRunSupported: event.routineRunSupported ?? false,
        workflowCatalogIdentifier: event.catalogWorkflowIdentifier ?? previous.workflowCatalogIdentifier,
        beat: "none",
        interaction: "default",
      };

    case "teaching":
      if (event.phase === "none") {
        return {
          ...previous,
          teachingPhase: "none",
          teachingStepIndex: null,
          teachingStepSummary: null,
          teachingStepsPreview: null,
          teachingStyle: null,
        };
      }
      return {
        ...previous,
        state: "aware",
        title: event.title,
        subtitle: event.subtitle ?? "",
        teachingPhase: event.phase,
        teachingStyle: event.teachingStyle ?? previous.teachingStyle,
        teachingStepIndex: event.stepIndex ?? previous.teachingStepIndex,
        teachingStepSummary: event.stepSummary ?? previous.teachingStepSummary,
        teachingStepsPreview: event.stepsPreview ?? previous.teachingStepsPreview,
        interaction: "default",
        beat: "none",
        showSuccessCheck: false,
        permissionActionLabel: null,
        errorMessage: null,
        journeySteps: null,
      };

    case "state": {
      const nextSubtitle = event.subtitle ?? "";
      const nextApplicationName = event.application ?? previous.applicationName;
      const nextJourneySteps = normalizeJourneySteps(event.journeySteps);
      const nextVerificationOutcome = event.verificationOutcome ?? "none";
      const nextRetrySupported = event.retrySupported ?? false;
      if (
        previous.state === event.state &&
        previous.title === event.title &&
        previous.subtitle === nextSubtitle &&
        previous.applicationName === nextApplicationName &&
        previous.beat === "none" &&
        previous.memoryPhase === "none" &&
        journeyFingerprint(previous.journeySteps) === journeyFingerprint(nextJourneySteps) &&
        previous.verificationOutcome === nextVerificationOutcome &&
        previous.retrySupported === nextRetrySupported
      ) {
        return previous;
      }

      const isExecutionState =
        event.state === "acting" ||
        event.state === "verifying" ||
        event.state === "success" ||
        event.state === "error" ||
        event.state === "permission" ||
        event.state === "thinking";

      const next: DexterHubViewModel = {
        ...previous,
        state: event.state,
        title: event.title,
        subtitle: event.subtitle ?? "",
        applicationName: event.application ?? previous.applicationName,
        interaction: isExecutionState ? "default" : resolveInteraction(event.interaction, previous.interaction),
        beat: isExecutionState ? "none" : previous.beat,
        showSuccessCheck: event.state === "success" && nextVerificationOutcome === "verified",
        permissionActionLabel: null,
        errorMessage: event.state === "error" ? event.subtitle ?? null : null,
        journeySteps: nextJourneySteps ?? (event.state === "idle" ? null : previous.journeySteps),
        retrySupported: nextRetrySupported,
        verificationOutcome: nextVerificationOutcome,
        voiceVisualOnly: event.voiceVisualOnly ?? false,
      };
      if (event.actionLabel) {
        next.permissionActionLabel = event.actionLabel;
      }
      if (event.state === "idle") {
        next.interaction = "default";
        next.beat = "none";
        next.memoryPhase = "none";
        next.journeySteps = null;
        next.verificationOutcome = "none";
        next.retrySupported = false;
        next.teachingPhase = "none";
        next.teachingStepsPreview = null;
      }
      return next;
    }

    default:
      return previous;
  }
}
