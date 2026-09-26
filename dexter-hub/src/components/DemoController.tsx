import type { DexterState } from "../types/dexterEvents";
import type { DemoHealthCheck } from "../state/demoHealth";
import type { MockDexterBridge } from "../services/mockDexterBridge";
import { MOCK_CORE_DEMO_SEQUENCE_ID } from "../services/mockDexterBridge";
import { DemoHealthPanel } from "./DemoHealthPanel";

const MANUAL_DEMO_STATES: DexterState[] = [
  "idle",
  "aware",
  "listening",
  "thinking",
  "acting",
  "verifying",
  "success",
  "permission",
  "error",
  "disconnected",
];

type DemoControllerProps = {
  mockBridge: MockDexterBridge | null;
  usesMockBridge: boolean;
  demoHealthChecks: DemoHealthCheck[];
  onRefreshDemoHealth: () => void;
  onResetDemo: () => void;
  onClose: () => void;
};

export function DemoController({
  mockBridge,
  usesMockBridge,
  demoHealthChecks,
  onRefreshDemoHealth,
  onResetDemo,
  onClose,
}: DemoControllerProps) {
  return (
    <div className="hub-demo-panel" role="dialog" aria-label="Demo controller">
      <h2>Demo lock</h2>

      <DemoHealthPanel checks={demoHealthChecks} onRefresh={onRefreshDemoHealth} />

      <div className="hub-demo-actions hub-demo-actions--reset">
        <button type="button" className="hub-touch-button hub-touch-button--secondary" onClick={onResetDemo}>
          Reset demo
        </button>
      </div>

      {usesMockBridge && mockBridge ? (
        <>
          <p className="hub-demo-mode-banner hub-demo-mode-banner--mock">
            Mock demo mode ({MOCK_CORE_DEMO_SEQUENCE_ID}) — not real Dexter verification.
          </p>

          <section className="hub-demo-section" aria-label="Core demo">
            <h3>Core demo</h3>
            <p className="hub-demo-section__hint">Mock fallback only — IDLE through SUCCESS.</p>
            <button
              type="button"
              className="hub-touch-button hub-touch-button--primary"
              onClick={() => mockBridge.runCoreDemo()}
            >
              Run core demo
            </button>
          </section>

          <section className="hub-demo-section" aria-label="Teach demo">
            <h3>Teach demo</h3>
            <button type="button" className="hub-touch-button hub-touch-button--secondary" onClick={() => mockBridge.runTeachDemo()}>
              Run teach demo
            </button>
          </section>

          <section className="hub-demo-section" aria-label="Memory demo">
            <h3>Memory demo</h3>
            <button type="button" className="hub-touch-button hub-touch-button--secondary" onClick={() => mockBridge.runMemoryDemo()}>
              Run memory demo
            </button>
          </section>

          <section className="hub-demo-section" aria-label="Manual states">
            <h3>Manual states</h3>
            <div className="hub-demo-grid">
              {MANUAL_DEMO_STATES.map((state) => (
                <button key={state} type="button" onClick={() => mockBridge.triggerState(state)}>
                  {state}
                </button>
              ))}
            </div>
            <button
              type="button"
              className="hub-touch-button hub-touch-button--secondary"
              onClick={() => mockBridge.setDisconnected?.(true)}
            >
              Simulate disconnect
            </button>
          </section>
        </>
      ) : (
        <p className="hub-demo-mode-banner hub-demo-mode-banner--live">
          Live Dexter — sequences run on your Mac. Use Reset demo to clear Hub presentation state only.
        </p>
      )}

      <div className="hub-demo-actions">
        <button type="button" className="hub-touch-button hub-touch-button--secondary" onClick={onClose}>
          Close
        </button>
      </div>
    </div>
  );
}
