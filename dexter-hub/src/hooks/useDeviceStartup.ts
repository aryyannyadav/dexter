import { useEffect, useState } from "react";
import { hubAmbientIdleTitle } from "../state/hubAmbientSession";

export type DeviceStartupPhase = "black" | "character" | "brand" | "greeting" | "done";

export function useDeviceStartup() {
  const [phase, setPhase] = useState<DeviceStartupPhase>("black");
  const greetingLine = hubAmbientIdleTitle;

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setPhase("done");
      return;
    }

    const timers = [
      window.setTimeout(() => setPhase("character"), 280),
      window.setTimeout(() => setPhase("brand"), 620),
      window.setTimeout(() => setPhase("greeting"), 980),
      window.setTimeout(() => setPhase("done"), 1680),
    ];

    return () => timers.forEach((timer) => window.clearTimeout(timer));
  }, []);

  return {
    startupPhase: phase,
    startupComplete: phase === "done",
    greetingLine,
  };
}
