import type { DexterHubViewModel } from "../types/dexterEvents";
import { defaultViewModel } from "./dexterState";
import { hubAmbientIdleSubtitle, hubAmbientIdleTitle } from "./hubAmbientSession";

/** Clears transient Hub presentation state without touching Mac memory or settings. */
export function resetHubDemoPresentationState(previous: DexterHubViewModel): DexterHubViewModel {
  return {
    ...defaultViewModel,
    connectionState: previous.connectionState,
    applicationName: previous.applicationName,
    watchingApplicationName: previous.watchingApplicationName,
    projectContextLabel: previous.projectContextLabel,
    projectContextName: previous.projectContextName,
    ambientFocusMode: previous.ambientFocusMode,
    title: hubAmbientIdleTitle,
    subtitle: hubAmbientIdleSubtitle,
  };
}
