type CompanionMenuProps = {
  anchor: DOMRect;
  isMuted: boolean;
  onSelect: (action: "ask" | "teach" | "help" | "act" | "mute" | "reconnect" | "about") => void;
  onClose: () => void;
};

export function CompanionMenu({ anchor, isMuted, onSelect, onClose }: CompanionMenuProps) {
  const menuWidth = 220;
  const left = Math.min(Math.max(anchor.left + anchor.width / 2 - menuWidth / 2, 16), window.innerWidth - menuWidth - 16);
  const top = Math.min(anchor.bottom + 12, window.innerHeight - 340);

  return (
    <>
      <button type="button" className="hub-scrim" aria-label="Close menu" onPointerUp={onClose} />
      <nav
        className="hub-overlay-menu"
        style={{ left, top, width: menuWidth }}
        aria-label="Companion actions"
      >
        {(["ask", "teach", "help", "act"] as const).map((action) => (
          <button key={action} type="button" className="hub-overlay-menu__item" onPointerUp={() => onSelect(action)}>
            {action.toUpperCase()}
          </button>
        ))}
        <hr />
        <button type="button" className="hub-overlay-menu__item" onPointerUp={() => onSelect("mute")}>
          {isMuted ? "Unmute" : "Mute"}
        </button>
        <button type="button" className="hub-overlay-menu__item" onPointerUp={() => onSelect("reconnect")}>
          Reconnect
        </button>
        <button type="button" className="hub-overlay-menu__item" onPointerUp={() => onSelect("about")}>
          About Dexter
        </button>
      </nav>
    </>
  );
}
