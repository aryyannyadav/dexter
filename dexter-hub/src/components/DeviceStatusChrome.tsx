import { devicePresentationStatus, useDevicePresentationClock } from "../hooks/useDevicePresentationClock";

function WifiIcon() {
  return (
    <svg className="hub-device-icon hub-device-icon--wifi" viewBox="0 0 24 24" aria-hidden>
      <path d="M12 18.5a1.75 1.75 0 1 0 0-3.5 1.75 1.75 0 0 0 0 3.5Z" fill="currentColor" />
      <path
        d="M8.2 14.1a6.2 6.2 0 0 1 7.6 0"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <path
        d="M5.1 11a10.5 10.5 0 0 1 13.8 0"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <path
        d="M2 7.8a14.8 14.8 0 0 1 20 0"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
    </svg>
  );
}

function BatteryIcon({ percent }: { percent: number }) {
  const fillWidth = Math.max(0, Math.min(100, percent));
  return (
    <span className="hub-device-battery" aria-hidden>
      <svg className="hub-device-icon hub-device-icon--battery" viewBox="0 0 28 14" aria-hidden>
        <rect x="0.75" y="2.75" width="22" height="8.5" rx="2" fill="none" stroke="currentColor" strokeWidth="1.2" />
        <rect x="23.5" y="5" width="2.5" height="4" rx="0.8" fill="currentColor" opacity="0.55" />
        <rect x="2.2" y="4.2" width={18.6 * (fillWidth / 100)} height="5.6" rx="1.2" fill="currentColor" opacity="0.85" />
      </svg>
      <span className="hub-device-battery__label">{percent}%</span>
    </span>
  );
}

export function DeviceStatusChrome() {
  const timeLabel = useDevicePresentationClock();
  const { batteryPercent, wifiLabel } = devicePresentationStatus;

  return (
    <header className="hub-device-chrome" aria-label="Presentation device status">
      <span className="hub-device-chrome__brand">DEXTER</span>
      <span className="hub-device-chrome__time" aria-label="Local time">
        {timeLabel}
      </span>
      <span className="hub-device-chrome__trailing">
        <span className="hub-device-chrome__wifi" aria-label={wifiLabel}>
          <WifiIcon />
        </span>
        <BatteryIcon percent={batteryPercent} />
      </span>
    </header>
  );
}
