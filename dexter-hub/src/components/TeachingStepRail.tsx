import type { DexterHubTeachingStepPreview } from "../types/dexterEvents";

type TeachingStepRailProps = {
  stepsPreview: DexterHubTeachingStepPreview[];
  activeStepIndex: number | null;
  currentStepSummary: string | null;
};

export function TeachingStepRail({ stepsPreview, activeStepIndex, currentStepSummary }: TeachingStepRailProps) {
  if (stepsPreview.length === 0 && !currentStepSummary) {
    return null;
  }

  if (stepsPreview.length > 0) {
    return (
      <ol className="hub-teaching-steps" aria-label="Lesson steps">
        {stepsPreview.map((stepPreview) => {
          const isActive = activeStepIndex === stepPreview.index;
          return (
            <li
              key={`${stepPreview.index}-${stepPreview.label}`}
              className={`hub-teaching-steps__item${isActive ? " hub-teaching-steps__item--active" : ""}`}
            >
              <span className="hub-teaching-steps__index">Step {stepPreview.index}</span>
              <span className="hub-teaching-steps__label">{stepPreview.label}</span>
            </li>
          );
        })}
      </ol>
    );
  }

  return currentStepSummary ? <p className="hub-teaching-current-step">{currentStepSummary}</p> : null;
}
