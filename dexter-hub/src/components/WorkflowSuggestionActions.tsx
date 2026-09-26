type WorkflowSuggestionActionsProps = {
  phase: "suggest" | "preview" | "routine";
  routineRunSupported: boolean;
  onAcceptRoutine: () => void;
  onDismissRoutine: () => void;
  onRunRoutine?: () => void;
};

export function WorkflowSuggestionActions({
  phase,
  routineRunSupported,
  onAcceptRoutine,
  onDismissRoutine,
  onRunRoutine,
}: WorkflowSuggestionActionsProps) {
  if (phase === "preview" || phase === "routine") {
    return (
      <div className="hub-workflow-actions" role="group" aria-label="Routine actions">
        {routineRunSupported && onRunRoutine ? (
          <button type="button" className="hub-workflow-actions__button" onClick={onRunRoutine}>
            Run
          </button>
        ) : null}
        <button
          type="button"
          className="hub-workflow-actions__button hub-workflow-actions__button--quiet"
          onClick={onDismissRoutine}
        >
          Not now
        </button>
      </div>
    );
  }

  return (
    <div className="hub-workflow-actions" role="group" aria-label="Routine suggestion">
      <button type="button" className="hub-workflow-actions__button" onClick={onAcceptRoutine}>
        Yes
      </button>
      <button
        type="button"
        className="hub-workflow-actions__button hub-workflow-actions__button--quiet"
        onClick={onDismissRoutine}
      >
        Not now
      </button>
    </div>
  );
}
