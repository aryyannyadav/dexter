import { useEffect, useState } from "react";
import { CompanionMenu } from "../components/CompanionMenu";
import { ConnectionIndicator } from "../components/ConnectionIndicator";
import { DeviceStatusChrome } from "../components/DeviceStatusChrome";
import { DexterCharacter } from "../components/DexterCharacter";
import { DexterControls } from "../components/DexterControls";
import { DexterDeviceStartupOverlay } from "../components/DexterDeviceStartupOverlay";
import { DexterStatus } from "../components/DexterStatus";
import { TeachingDepthSelector } from "../components/TeachingDepthSelector";
import { DemoController } from "../components/DemoController";
import { IdentityCard } from "../components/IdentityCard";
import { useDeviceStartup } from "../hooks/useDeviceStartup";
import { useDexterHub } from "../hooks/useDexterHub";
import { usePresentationMode } from "../hooks/usePresentationMode";
import { companionShellStateClass, presentDexterHub } from "../state/dexterPresentation";

function isCompanionActiveState(state: string): boolean {
  return state !== "idle" && state !== "disconnected" && state !== "success";
}

export function HubHome() {
  const {
    mockBridge,
    usesMockBridge,
    isMuted,
    viewModel,
    demoHealthChecks,
    allow,
    deny,
    retry,
    reconnect,
    resetDemo,
    refreshDemoHealth,
    sendMenuAction,
    setTeachingDepth,
    viewMemoryRecord,
    forgetMemoryRecord,
    acceptWorkflowRoutine,
    dismissWorkflowRoutine,
    runWorkflowRoutine,
  } = useDexterHub();

  const { presentationMode, demoOpen, setDemoOpen, togglePresentation } = usePresentationMode();
  const { startupPhase, startupComplete, greetingLine } = useDeviceStartup();
  const [menuOpen, setMenuOpen] = useState(false);
  const [menuAnchor, setMenuAnchor] = useState<DOMRect | null>(null);
  const [identityOpen, setIdentityOpen] = useState(false);

  const deviceMode = presentationMode;
  const showDeveloperChrome = !deviceMode;

  const shellClass = [
    deviceMode ? "hub-shell hub-shell--presentation hub-shell--device" : "hub-shell",
    isMuted ? "hub-shell--muted" : "",
    isCompanionActiveState(viewModel.state) ? "hub-shell--awake" : "hub-shell--settled",
    companionShellStateClass(
      viewModel.state,
      viewModel.beat,
      viewModel.memoryPhase,
      viewModel.teachingPhase,
      viewModel.workflowSuggestionPhase,
    ),
    startupComplete ? "hub-shell--started" : "hub-shell--booting",
    viewModel.state === "idle" ? "hub-shell--ambient-idle" : "",
  ]
    .filter(Boolean)
    .join(" ");

  const presentation = presentDexterHub(viewModel);

  useEffect(() => {
    if (!demoOpen || presentationMode) return;
    refreshDemoHealth();
  }, [demoOpen, presentationMode, refreshDemoHealth]);

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (event.key !== "Escape") return;
      setMenuOpen(false);
      setMenuAnchor(null);
      setIdentityOpen(false);
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  function handleCharacterTap(anchor: DOMRect) {
    if (menuOpen) {
      setMenuOpen(false);
      setMenuAnchor(null);
      return;
    }
    setMenuAnchor(anchor);
    setMenuOpen(true);
  }

  function closeMenu() {
    setMenuOpen(false);
    setMenuAnchor(null);
  }

  return (
    <div className={shellClass}>
      <DexterDeviceStartupOverlay phase={startupPhase} greetingLine={greetingLine} />

      <div className={`hub-layout${startupComplete ? "" : " hub-layout--hidden"}`}>
        <DeviceStatusChrome />

        <div className="hub-dexter-link-row">
          <ConnectionIndicator connectionState={viewModel.connectionState} isMuted={isMuted} />
        </div>

        <main className="hub-hero">
          <div className="hub-hero__character">
            <DexterCharacter
              state={viewModel.state}
              beat={viewModel.beat}
              memoryPhase={viewModel.memoryPhase}
              teachingPhase={viewModel.teachingPhase}
              watchingApplication={null}
              onTap={handleCharacterTap}
              onLongPress={() => {
                closeMenu();
                setIdentityOpen(true);
              }}
            />
          </div>
          <div className="hub-hero__status">
            <DexterStatus
              viewModel={viewModel}
              watchingApplication={presentation.watchingApplication}
              onViewMemory={viewMemoryRecord}
              onForgetMemory={forgetMemoryRecord}
              onAcceptWorkflowRoutine={acceptWorkflowRoutine}
              onDismissWorkflowRoutine={dismissWorkflowRoutine}
              onRunWorkflowRoutine={runWorkflowRoutine}
            />
          </div>
        </main>

        <footer className="hub-float-dock hub-float-dock--controls">
          {viewModel.teachingPhase !== "none" ? (
            <TeachingDepthSelector
              selectedDepth={viewModel.teachingDepthSelection}
              onSelectDepth={setTeachingDepth}
            />
          ) : null}
          <DexterControls
            state={viewModel.state}
            retrySupported={viewModel.retrySupported}
            onAllow={allow}
            onDeny={deny}
            onRetry={retry}
            onReconnect={reconnect}
          />
        </footer>
      </div>

      {demoOpen && !presentationMode ? (
        <DemoController
          mockBridge={mockBridge}
          usesMockBridge={usesMockBridge}
          demoHealthChecks={demoHealthChecks}
          onRefreshDemoHealth={refreshDemoHealth}
          onResetDemo={resetDemo}
          onClose={() => setDemoOpen(false)}
        />
      ) : null}

      {menuOpen && menuAnchor ? (
        <CompanionMenu
          anchor={menuAnchor}
          isMuted={isMuted}
          onClose={closeMenu}
          onSelect={(action) => {
            closeMenu();
            if (action === "about") {
              setIdentityOpen(true);
              return;
            }
            sendMenuAction(action);
          }}
        />
      ) : null}

      {identityOpen ? <IdentityCard onClose={() => setIdentityOpen(false)} /> : null}

      {showDeveloperChrome ? (
        <button
          type="button"
          className="hub-presentation-toggle"
          onClick={togglePresentation}
          aria-pressed={presentationMode}
        >
          Device mode off
        </button>
      ) : null}
    </div>
  );
}
