import type { DemoHealthCheck } from "../state/demoHealth";
import { DEMO_HEALTH_LABELS, demoHealthMark } from "../state/demoHealth";

type DemoHealthPanelProps = {
  checks: DemoHealthCheck[];
  onRefresh: () => void;
};

export function DemoHealthPanel({ checks, onRefresh }: DemoHealthPanelProps) {
  return (
    <section className="hub-demo-health" aria-label="Dexter demo health">
      <div className="hub-demo-health__header">
        <h3>Dexter Demo Health</h3>
        <button type="button" className="hub-demo-health__refresh" onClick={onRefresh}>
          Refresh
        </button>
      </div>
      <ul className="hub-demo-health__list">
        {checks.map((check) => (
          <li key={check.id} className={`hub-demo-health__row hub-demo-health__row--${check.status}`}>
            <span className="hub-demo-health__label">{DEMO_HEALTH_LABELS[check.id]}</span>
            <span className="hub-demo-health__mark" aria-hidden>
              {demoHealthMark(check.status)}
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}
