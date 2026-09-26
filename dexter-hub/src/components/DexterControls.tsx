import type { DexterState } from "../types/dexterEvents";
import { PermissionCard } from "./PermissionCard";

type DexterControlsProps = {
  state: DexterState;
  retrySupported: boolean;
  onAllow: () => void;
  onDeny: () => void;
  onRetry: () => void;
  onReconnect: () => void;
};

export function DexterControls({
  state,
  retrySupported,
  onAllow,
  onDeny,
  onRetry,
  onReconnect,
}: DexterControlsProps) {
  if (state === "permission") {
    return <PermissionCard onAllow={onAllow} onDeny={onDeny} />;
  }

  if (state === "error" && retrySupported) {
    return (
      <div className="hub-action-row">
        <button type="button" className="hub-touch-button hub-touch-button--primary" onPointerUp={onRetry}>
          Try again
        </button>
      </div>
    );
  }

  if (state === "disconnected") {
    return (
      <div className="hub-action-row">
        <button type="button" className="hub-touch-button hub-touch-button--primary" onPointerUp={onReconnect}>
          Reconnect
        </button>
      </div>
    );
  }

  return null;
}
