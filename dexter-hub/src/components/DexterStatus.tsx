import { presentDexterHub } from "../state/dexterPresentation";
import type { DexterHubViewModel } from "../types/dexterEvents";
import { ActionJourneyTimeline } from "./ActionJourneyTimeline";
import { MemoryMomentActions } from "./MemoryMomentActions";
import { TeachingStepRail } from "./TeachingStepRail";
import { WorkflowSuggestionActions } from "./WorkflowSuggestionActions";

type DexterStatusProps = {
  viewModel: DexterHubViewModel;
  watchingApplication?: string | null;
  onViewMemory?: (memoryRecordId: string) => void;
  onForgetMemory?: (memoryRecordId: string) => void;
  onAcceptWorkflowRoutine?: () => void;
  onDismissWorkflowRoutine?: () => void;
  onRunWorkflowRoutine?: () => void;
};

export function DexterStatus({
  viewModel,
  watchingApplication = null,
  onViewMemory,
  onForgetMemory,
  onAcceptWorkflowRoutine,
  onDismissWorkflowRoutine,
  onRunWorkflowRoutine,
}: DexterStatusProps) {
  const presentation = presentDexterHub(viewModel);
  const showListeningIndicator = viewModel.state === "listening" && viewModel.beat === "none";
  const showContextRail =
    Boolean(watchingApplication) &&
    (viewModel.state === "idle" ||
      (viewModel.state === "aware" && viewModel.beat === "none" && viewModel.workflowSuggestionPhase === "none"));
  const showProjectRail =
    viewModel.projectContextLabel !== null &&
    viewModel.projectContextName !== null &&
    viewModel.projectContextName.trim().length > 0;

  const showMemoryActions =
    viewModel.memoryPhase === "remembering" &&
    viewModel.memoryActionsSupported &&
    viewModel.memoryRecordId !== null &&
    onViewMemory !== undefined &&
    onForgetMemory !== undefined;

  const showWorkflowSuggestion =
    viewModel.workflowSuggestionPhase !== "none" &&
    !viewModel.ambientFocusMode &&
    onAcceptWorkflowRoutine !== undefined &&
    onDismissWorkflowRoutine !== undefined;

  const showActionJourney =
    viewModel.journeySteps !== null &&
    viewModel.journeySteps.length > 0 &&
    (viewModel.state === "thinking" ||
      viewModel.state === "acting" ||
      viewModel.state === "verifying" ||
      viewModel.state === "permission" ||
      viewModel.state === "error" ||
      (viewModel.state === "success" && viewModel.showSuccessCheck));

  const journeyFailureHint =
    viewModel.state === "error" &&
    viewModel.journeySteps?.some((step) => step.label === "VERIFY" && step.status === "failed")
      ? "could not verify"
      : null;

  return (
    <div
      className={`hub-status-block hub-status-block--${viewModel.state}${viewModel.beat !== "none" ? " hub-status-block--moment" : ""}${viewModel.memoryPhase !== "none" ? " hub-status-block--memory" : ""}${viewModel.workflowSuggestionPhase !== "none" ? " hub-status-block--workflow" : ""}${viewModel.state === "permission" ? " hub-status-block--permission-prompt" : ""}`}
      aria-live="polite"
      aria-atomic="true"
    >
      <h1 className="hub-title">{presentation.title}</h1>
      {presentation.subtitle ? <p className="hub-subtitle">{presentation.subtitle}</p> : null}

      {showMemoryActions && viewModel.memoryRecordId ? (
        <MemoryMomentActions
          memoryRecordId={viewModel.memoryRecordId}
          onViewMemory={onViewMemory}
          onForgetMemory={onForgetMemory}
        />
      ) : null}

      {showWorkflowSuggestion ? (
        <WorkflowSuggestionActions
          phase={
            viewModel.workflowSuggestionPhase === "routine"
              ? "routine"
              : viewModel.workflowSuggestionPhase === "preview"
                ? "preview"
                : "suggest"
          }
          routineRunSupported={viewModel.workflowRoutineRunSupported}
          onAcceptRoutine={onAcceptWorkflowRoutine}
          onDismissRoutine={onDismissWorkflowRoutine}
          onRunRoutine={onRunWorkflowRoutine}
        />
      ) : null}

      {showProjectRail ? (
        <div className="hub-context-rail hub-context-rail--project" aria-label={`${viewModel.projectContextLabel} ${viewModel.projectContextName}`}>
          <span className="hub-context-rail__label">{viewModel.projectContextLabel}</span>
          <span className="hub-context-rail__value">{viewModel.projectContextName}</span>
        </div>
      ) : null}

      {showContextRail ? (
        <div className="hub-context-rail hub-context-rail--watching" aria-label={`Watching ${watchingApplication}`}>
          <span className="hub-context-rail__label">Watching</span>
          <span className="hub-context-rail__value">{watchingApplication}</span>
        </div>
      ) : null}

      {viewModel.teachingPhase !== "none" ? (
        <TeachingStepRail
          stepsPreview={viewModel.teachingStepsPreview ?? []}
          activeStepIndex={viewModel.teachingStepIndex}
          currentStepSummary={viewModel.teachingStepSummary}
        />
      ) : null}

      {showActionJourney && viewModel.journeySteps ? (
        <ActionJourneyTimeline
          journeySteps={viewModel.journeySteps}
          fadeOut={viewModel.state === "success"}
          failureHint={journeyFailureHint}
        />
      ) : null}

      {showListeningIndicator ? (
        <div className="hub-listening-dot" aria-hidden>
          <span />
          Listening
        </div>
      ) : null}

      {viewModel.showSuccessCheck && viewModel.state === "success" ? (
        <div className="hub-success-mark" aria-hidden>
          ✓
        </div>
      ) : null}
    </div>
  );
}
