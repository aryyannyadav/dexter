import { useEffect, useState } from "react";

function formatDeviceTime(date: Date): string {
  return new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
    hour12: undefined,
  }).format(date);
}

export function useDevicePresentationClock() {
  const [timeLabel, setTimeLabel] = useState(() => formatDeviceTime(new Date()));

  useEffect(() => {
    function tick() {
      setTimeLabel(formatDeviceTime(new Date()));
    }

    tick();
    const interval = window.setInterval(tick, 60_000);
    return () => window.clearInterval(interval);
  }, []);

  return timeLabel;
}

export const devicePresentationStatus = {
  batteryPercent: 82,
  wifiLabel: "Connected",
} as const;
