const TIME_GREETING_SESSION_KEY = "dexter-hub-time-greeting-shown";

export function timeAwareIdleGreetingForSession(): string | null {
  if (typeof window === "undefined") return null;
  if (window.sessionStorage.getItem(TIME_GREETING_SESSION_KEY) === "true") {
    return null;
  }
  window.sessionStorage.setItem(TIME_GREETING_SESSION_KEY, "true");
  return timeAwareIdleGreetingForHour(new Date().getHours());
}

export function timeAwareIdleGreetingForHour(hour: number): string {
  if (hour >= 5 && hour < 12) return "good morning.";
  if (hour >= 12 && hour < 17) return "hey.";
  if (hour >= 17 && hour < 22) return "still working?";
  return "you're still here.";
}

export const hubAmbientIdleTitle = "hey, I'm here." as const;
export const hubAmbientIdleSubtitle = "your digital companion" as const;
export const hubAmbientFocusIdleTitle = "I'm here if you need me." as const;
