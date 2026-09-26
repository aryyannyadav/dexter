type PermissionCardProps = {
  onAllow: () => void;
  onDeny: () => void;
};

export function PermissionCard({ onAllow, onDeny }: PermissionCardProps) {
  return (
    <div className="hub-action-row hub-permission-actions" role="group" aria-label="Permission">
        <button type="button" className="hub-touch-button hub-touch-button--primary hub-touch-button--allow" onPointerUp={onAllow}>
          Allow
        </button>
        <button type="button" className="hub-touch-button hub-touch-button--secondary hub-touch-button--deny" onPointerUp={onDeny}>
          Not now
        </button>
    </div>
  );
}
