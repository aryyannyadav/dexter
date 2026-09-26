import type { DexterHubJourneyStep } from "../types/dexterEvents";

type ActionJourneyTimelineProps = {
  journeySteps: DexterHubJourneyStep[];
  fadeOut?: boolean;
  failureHint?: string | null;
};

function journeyStepMark(journeyStep: DexterHubJourneyStep): string {
  switch (journeyStep.status) {
    case "done":
      return "✓";
    case "active":
      return "●";
    case "failed":
      return "×";
    case "pending":
    default:
      return "○";
  }
}

export function ActionJourneyTimeline({
  journeySteps,
  fadeOut = false,
  failureHint = null,
}: ActionJourneyTimelineProps) {
  if (journeySteps.length === 0) {
    return null;
  }

  const failedVerifyStep = journeySteps.some(
    (journeyStep) => journeyStep.label === "VERIFY" && journeyStep.status === "failed",
  );

  return (
    <div
      className={`hub-action-journey-wrap${fadeOut ? " hub-action-journey-wrap--fade-out" : ""}`}
    >
      <ol className="hub-action-journey" aria-label="Execution journey">
        {journeySteps.map((journeyStep) => (
          <li
            key={journeyStep.label}
            className={`hub-action-journey__step hub-action-journey__step--${journeyStep.status}`}
          >
            <span className="hub-action-journey__label">{journeyStep.label}</span>
            <span className="hub-action-journey__mark" aria-hidden>
              {journeyStepMark(journeyStep)}
            </span>
          </li>
        ))}
      </ol>
      {failedVerifyStep && failureHint ? (
        <p className="hub-action-journey__failure-hint">{failureHint}</p>
      ) : null}
    </div>
  );
}
