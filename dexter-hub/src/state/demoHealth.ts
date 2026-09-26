import type { DexterConnectionState } from "../types/dexterEvents";

export type DemoHealthCheckId =
  | "DEXTER_APP"
  | "WEBSOCKET"
  | "HUB"
  | "OPENCLAW"
  | "SCREEN"
  | "MICROPHONE"
  | "STT"
  | "TTS"
  | "OLLAMA"
  | "VERIFICATION";

export type DemoHealthStatus = "ok" | "fail" | "unknown";

export type DemoHealthCheck = {
  id: DemoHealthCheckId;
  status: DemoHealthStatus;
};

export const DEMO_HEALTH_ROW_ORDER: DemoHealthCheckId[] = [
  "DEXTER_APP",
  "WEBSOCKET",
  "HUB",
  "OPENCLAW",
  "SCREEN",
  "MICROPHONE",
  "STT",
  "TTS",
  "OLLAMA",
  "VERIFICATION",
];

export const DEMO_HEALTH_LABELS: Record<DemoHealthCheckId, string> = {
  DEXTER_APP: "DEXTER APP",
  WEBSOCKET: "WEBSOCKET",
  HUB: "HUB",
  OPENCLAW: "OPENCLAW",
  SCREEN: "SCREEN",
  MICROPHONE: "MICROPHONE",
  STT: "STT",
  TTS: "TTS",
  OLLAMA: "OLLAMA",
  VERIFICATION: "VERIFICATION",
};

export function mergeDemoHealthChecks(
  connectionState: DexterConnectionState,
  usesMockBridge: boolean,
  macChecks: DemoHealthCheck[],
): DemoHealthCheck[] {
  const macById = new Map(macChecks.map((check) => [check.id, check.status]));

  const websocketStatus: DemoHealthStatus =
    connectionState === "connected" ? "ok" : connectionState === "connecting" ? "unknown" : "fail";

  const dexterAppStatus: DemoHealthStatus =
    usesMockBridge ? "unknown" : connectionState === "connected" ? "ok" : "fail";

  const rows: DemoHealthCheck[] = [
    { id: "DEXTER_APP", status: dexterAppStatus },
    { id: "WEBSOCKET", status: websocketStatus },
    { id: "HUB", status: "ok" },
  ];

  for (const rowId of DEMO_HEALTH_ROW_ORDER) {
    if (rowId === "DEXTER_APP" || rowId === "WEBSOCKET" || rowId === "HUB") {
      continue;
    }
    if (usesMockBridge) {
      rows.push({ id: rowId, status: "unknown" });
      continue;
    }
    if (connectionState !== "connected") {
      rows.push({ id: rowId, status: "unknown" });
      continue;
    }
    const macStatus = macById.get(rowId);
    if (macStatus === "ok" || macStatus === "fail") {
      rows.push({ id: rowId, status: macStatus });
    } else if (rowId === "OLLAMA" && !macById.has("OLLAMA")) {
      rows.push({ id: rowId, status: "unknown" });
    } else {
      rows.push({ id: rowId, status: "unknown" });
    }
  }

  return rows;
}

export function demoHealthMark(status: DemoHealthStatus): string {
  switch (status) {
    case "ok":
      return "✓";
    case "fail":
      return "×";
    case "unknown":
    default:
      return "—";
  }
}

export function parseDemoHealthWireChecks(
  checks: Array<{ id?: string; status?: string }> | undefined,
): DemoHealthCheck[] {
  if (!checks?.length) return [];
  const parsed: DemoHealthCheck[] = [];
  for (const check of checks) {
    const id = check.id as DemoHealthCheckId | undefined;
    if (!id || !DEMO_HEALTH_ROW_ORDER.includes(id)) continue;
    const status = check.status;
    if (status === "ok" || status === "fail") {
      parsed.push({ id, status });
    }
  }
  return parsed;
}
