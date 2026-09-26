import { useCallback, useEffect, useState } from "react";

const PRESENTATION_KEY = "dexter-hub-presentation";

export function usePresentationMode() {
  const [presentationMode, setPresentationMode] = useState(() => {
    if (typeof window === "undefined") return true;
    const stored = window.localStorage.getItem(PRESENTATION_KEY);
    if (stored === null) return true;
    return stored !== "false";
  });

  const [demoOpen, setDemoOpen] = useState(false);

  const togglePresentation = useCallback(() => {
    setPresentationMode((previous) => {
      const next = !previous;
      window.localStorage.setItem(PRESENTATION_KEY, String(next));
      return next;
    });
  }, []);

  useEffect(() => {
    if (presentationMode) {
      setDemoOpen(false);
    }
  }, [presentationMode]);

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      const isDemoShortcut =
        (event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === "d";
      const isDeviceModeToggle =
        (event.metaKey || event.ctrlKey) && event.shiftKey && event.key.toLowerCase() === "p";
      if (isDemoShortcut) {
        event.preventDefault();
        if (presentationMode) {
          return;
        }
        setDemoOpen((open) => !open);
      }
      if (isDeviceModeToggle) {
        event.preventDefault();
        setPresentationMode((previous) => {
          const next = !previous;
          window.localStorage.setItem(PRESENTATION_KEY, String(next));
          return next;
        });
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [presentationMode]);

  return {
    presentationMode,
    demoOpen,
    setDemoOpen,
    togglePresentation,
  };
}
