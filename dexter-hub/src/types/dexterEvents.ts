export type DexterState =
  | "idle"
  | "aware"
  | "listening"
  | "thinking"
  | "acting"
  | "verifying"
  | "success"
  | "permission"
  | "speaking"
  | "error"
  | "disconnected";

export type DexterConnectionState = "connected" | "connecting" | "disconnected";

export type DexterHubInteraction = "default" | "pointer";

export type DexterHubBeat =
  | "none"
  | "understandingLook"
  | "understandingGotIt"
  | "answer"
  | "targetUncertain"
  | "actionCanDo"
  | "actionWantMeTo";

export type DexterHubJourneyStepStatus = "pending" | "active" | "done" | "failed";

export type DexterHubJourneyStep = {
  label: string;
  status: DexterHubJourneyStepStatus;
};

export type DexterHubVerificationOutcome = "none" | "verified" | "partial" | "failed";

export type DexterHubMemoryPhase = "none" | "remembering" | "recalled";

export type DexterHubTeachingPhase =
  | "none"
  | "coaching"
  | "explaining"
  | "yourTurn"
  | "affirmation"
  | "step";

export type DexterHubTeachingStepPreview = {
  index: number;
  label: string;
};

export type DexterHubTeachingDepth = "eli5" | "simple" | "normal" | "technical" | "expert";

export type DexterHubEvent =
  | {
      type: "state";
      state: DexterState;
      title: string;
      subtitle?: string;
      actionLabel?: string;
      application?: string;
      interaction?: DexterHubInteraction;
      journeySteps?: DexterHubJourneyStep[];
      retrySupported?: boolean;
      verificationOutcome?: DexterHubVerificationOutcome;
      voiceVisualOnly?: boolean;
    }
  | {
      type: "context";
      application?: string;
      title: string;
      subtitle?: string;
      interaction?: DexterHubInteraction;
    }
  | {
      type: "ambient";
      beat: "understandingLook" | "understandingGotIt" | "answer" | "targetUncertain" | "actionCanDo" | "actionWantMeTo";
      state: DexterState;
      title: string;
      subtitle?: string;
      application?: string;
      interaction?: DexterHubInteraction;
    }
  | {
      type: "permission";
      title: string;
      subtitle: string;
      actionLabel: string;
      interaction?: DexterHubInteraction;
      journeySteps?: DexterHubJourneyStep[];
    }
  | {
      type: "memory";
      phase: "remembering" | "recalled";
      title: string;
      subtitle?: string;
      memoryRecordId?: string;
      memoryActionsSupported?: boolean;
      preferenceReflection?: string;
    }
  | {
      type: "projectContext";
      label: string;
      projectName: string;
    }
  | {
      type: "watching";
      application: string;
    }
  | {
      type: "ambientFocus";
      focusMode: boolean;
    }
  | {
      type: "workflowSuggestion";
      phase: "none" | "suggest" | "preview" | "routine";
      title: string;
      subtitle?: string;
      routineDisplayName?: string;
      trustPreview?: string;
      routineRunSupported?: boolean;
      catalogWorkflowIdentifier?: string;
    }
  | {
      type: "teaching";
      phase: DexterHubTeachingPhase;
      title: string;
      subtitle?: string;
      teachingStyle?: string;
      stepIndex?: number;
      stepSummary?: string;
      stepsPreview?: DexterHubTeachingStepPreview[];
    }
  | {
      type: "connection";
      connectionState: DexterConnectionState;
    }
  | {
      type: "demoHealth";
      checks: Array<{ id: string; status: string }>;
    };

export type DexterHubViewModel = {
  state: DexterState;
  title: string;
  subtitle: string;
  applicationName: string | null;
  connectionState: DexterConnectionState;
  permissionActionLabel: string | null;
  errorMessage: string | null;
  showSuccessCheck: boolean;
  interaction: DexterHubInteraction;
  beat: DexterHubBeat;
  memoryPhase: DexterHubMemoryPhase;
  memoryRecordId: string | null;
  memoryActionsSupported: boolean;
  memoryPreferenceReflection: string | null;
  projectContextLabel: string | null;
  projectContextName: string | null;
  voiceVisualOnly: boolean;
  workflowSuggestionPhase: "none" | "suggest" | "preview" | "routine";
  workflowRoutineName: string | null;
  workflowTrustPreview: string | null;
  workflowRoutineRunSupported: boolean;
  workflowCatalogIdentifier: string | null;
  ambientFocusMode: boolean;
  watchingApplicationName: string | null;
  journeySteps: DexterHubJourneyStep[] | null;
  retrySupported: boolean;
  verificationOutcome: DexterHubVerificationOutcome;
  teachingPhase: DexterHubTeachingPhase;
  teachingStyle: string | null;
  teachingStepIndex: number | null;
  teachingStepSummary: string | null;
  teachingStepsPreview: DexterHubTeachingStepPreview[] | null;
  teachingDepthSelection: DexterHubTeachingDepth;
};

export type DexterCommand =
  | { type: "allow" }
  | { type: "deny" }
  | { type: "retry" }
  | { type: "reconnect" }
  | { type: "teachingStyle"; style: DexterHubTeachingDepth }
  | { type: "memoryAction"; action: "view" | "forget"; memoryRecordId: string }
  | {
      type: "workflowSuggestionResponse";
      response: "yes" | "notNow" | "run";
      catalogWorkflowIdentifier?: string;
    }
  | { type: "menu"; action: "ask" | "teach" | "help" | "act" | "mute" | "reconnect" | "about" }
  | { type: "requestDemoHealth" };
