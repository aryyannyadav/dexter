import type { DexterConnectionState } from "../types/dexterEvents";

type ConnectionIndicatorProps = {
  connectionState: DexterConnectionState;
  isMuted?: boolean;
};

export function ConnectionIndicator({ connectionState, isMuted = false }: ConnectionIndicatorProps) {
  const label =
    connectionState === "connected"
      ? isMuted
        ? "Connected · Muted"
        : "Connected"
      : connectionState === "connecting"
        ? "Connecting"
        : "Disconnected";

  const stateClass =
    connectionState === "connected"
      ? "hub-connection--online"
      : connectionState === "connecting"
        ? "hub-connection--connecting"
        : "hub-connection--offline";

  return (
    <div className={`hub-connection ${stateClass}`} aria-label={`Dexter ${label}`}>
      <span className="hub-connection__dot" aria-hidden />
      <span className="hub-connection__label">{label}</span>
    </div>
  );
}
