import { useEffect, useRef, useState } from "react";
import { characterAnimationClass, stateCharacterAssetPath } from "../state/dexterState";
import type { DexterHubBeat, DexterHubTeachingPhase, DexterHubViewModel, DexterState } from "../types/dexterEvents";

type DexterCharacterProps = {
  state: DexterState;
  beat: DexterHubBeat;
  memoryPhase: DexterHubViewModel["memoryPhase"];
  teachingPhase: DexterHubTeachingPhase;
  watchingApplication: string | null;
  onTap: (anchor: DOMRect) => void;
  onLongPress: () => void;
};

const LONG_PRESS_MS = 600;
const LONG_PRESS_MOVE_THRESHOLD_PX = 16;

export function DexterCharacter({ state, beat, memoryPhase, teachingPhase, watchingApplication: _watchingApplication, onTap, onLongPress }: DexterCharacterProps) {
  const imagePath = stateCharacterAssetPath(state, beat, teachingPhase);
  const animationClass = characterAnimationClass(state, beat, teachingPhase, memoryPhase);
  const previousStateRef = useRef<DexterState>(state);
  const [isTransitioning, setIsTransitioning] = useState(false);
  const [isPressed, setIsPressed] = useState(false);
  const suppressTapRef = useRef(false);

  useEffect(() => {
    if (previousStateRef.current === state) return;
    previousStateRef.current = state;
    setIsTransitioning(true);
    const timer = window.setTimeout(() => setIsTransitioning(false), 520);
    return () => window.clearTimeout(timer);
  }, [state]);

  function handlePointerDown(event: React.PointerEvent<HTMLButtonElement>) {
    if (event.pointerType === "mouse" && event.button !== 0) {
      return;
    }

    event.preventDefault();
    const target = event.currentTarget;
    const startX = event.clientX;
    const startY = event.clientY;
    let longPressFired = false;
    setIsPressed(true);

    const timer = window.setTimeout(() => {
      longPressFired = true;
      suppressTapRef.current = true;
      setIsPressed(false);
      onLongPress();
    }, LONG_PRESS_MS);

    function clearTimer() {
      window.clearTimeout(timer);
      setIsPressed(false);
      if (target.hasPointerCapture(event.pointerId)) {
        target.releasePointerCapture(event.pointerId);
      }
      target.removeEventListener("pointerup", onPointerUp);
      target.removeEventListener("pointercancel", onPointerUp);
      target.removeEventListener("pointermove", onPointerMove);
    }

    function onPointerMove(moveEvent: PointerEvent) {
      const deltaX = Math.abs(moveEvent.clientX - startX);
      const deltaY = Math.abs(moveEvent.clientY - startY);
      if (deltaX > LONG_PRESS_MOVE_THRESHOLD_PX || deltaY > LONG_PRESS_MOVE_THRESHOLD_PX) {
        clearTimer();
      }
    }

    function onPointerUp() {
      clearTimer();
      if (longPressFired || suppressTapRef.current) {
        window.setTimeout(() => {
          suppressTapRef.current = false;
        }, 320);
        return;
      }
      onTap(target.getBoundingClientRect());
    }

    target.setPointerCapture(event.pointerId);
    target.addEventListener("pointerup", onPointerUp);
    target.addEventListener("pointercancel", onPointerUp);
    target.addEventListener("pointermove", onPointerMove);
  }

  return (
    <div
      className={`hub-character-stage hub-character-stage--${state}${isTransitioning ? " hub-character-stage--transition" : ""}${beat !== "none" ? ` hub-character-stage--beat-${beat}` : ""}${memoryPhase !== "none" ? ` hub-character-stage--memory-${memoryPhase}` : ""}${teachingPhase !== "none" ? " hub-character-stage--teaching" : ""}`}
    >
      <div
        className={`hub-ambient-glow hub-ambient-glow--${state}${teachingPhase !== "none" ? " hub-ambient-glow--teaching" : ""}`}
        aria-hidden
      />
      {teachingPhase !== "none" ? <div className="hub-teaching-motif" aria-hidden /> : null}
      {memoryPhase !== "none" ? (
        <div className="hub-memory-motif" aria-hidden>
          <span className="hub-memory-motif__spark" />
        </div>
      ) : null}
      {state === "listening" || state === "permission" ? (
        <div className="hub-listening-aura" aria-hidden>
          <span />
          <span />
        </div>
      ) : null}
      <button
        type="button"
        className={`hub-character-hit${isPressed ? " hub-character-hit--pressed" : ""}`}
        aria-label="Dexter companion. Tap for menu, long press for about."
        onPointerDown={handlePointerDown}
      >
        <div className="hub-character-optical">
          <img
            className={`hub-character-image ${animationClass}${isTransitioning ? " hub-character-image--transition" : ""}`}
            src={imagePath}
            alt=""
            draggable={false}
          />
        </div>
      </button>
    </div>
  );
}
