import type { DeviceStartupPhase } from "../hooks/useDeviceStartup";

type DexterDeviceStartupOverlayProps = {
  phase: DeviceStartupPhase;
  greetingLine: string;
};

export function DexterDeviceStartupOverlay({ phase, greetingLine }: DexterDeviceStartupOverlayProps) {
  if (phase === "done") {
    return null;
  }

  return (
    <div className={`hub-startup hub-startup--${phase}`} aria-hidden>
      <div className="hub-startup__inner">
        {phase === "character" || phase === "brand" || phase === "greeting" ? (
          <img className="hub-startup__character" src="/characters/idle.png" alt="" draggable={false} />
        ) : null}
        {phase === "brand" || phase === "greeting" ? (
          <p className="hub-startup__brand">DEXTER</p>
        ) : null}
        {phase === "greeting" ? <p className="hub-startup__greeting">{greetingLine}</p> : null}
      </div>
    </div>
  );
}
