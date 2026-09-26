import type { DexterHubViewModel, DexterState } from "../types/dexterEvents";
import {
  hubAmbientFocusIdleTitle,
  hubAmbientIdleSubtitle,
  hubAmbientIdleTitle,
} from "./hubAmbientSession";

export type DexterHubPresentation = {
  title: string;
  subtitle: string | null;
  watchingApplication: string | null;
};

const GENERIC_THINKING_SUBTITLES = new Set([
  "understanding what you're looking at",
  "working on your request",
  "gathering context",
  "planning next steps",
]);

export function presentDexterHub(viewModel: DexterHubViewModel): DexterHubPresentation {
  if (viewModel.ambientFocusMode && viewModel.state === "idle") {
    return {
      title: hubAmbientFocusIdleTitle,
      subtitle: hubAmbientIdleSubtitle,
      watchingApplication: resolveWatchingApplication(viewModel),
    };
  }

  if (viewModel.workflowSuggestionPhase !== "none" && !viewModel.ambientFocusMode) {
    return presentWorkflowSuggestionHub(viewModel);
  }

  if (viewModel.teachingPhase !== "none") {
    return presentTeachingHub(viewModel);
  }

  if (viewModel.memoryPhase === "remembering") {
    return {
      title: "I'll remember that.",
      subtitle: viewModel.subtitle.trim() || null,
      watchingApplication: null,
    };
  }

  if (viewModel.memoryPhase === "recalled") {
    const recallSubtitle =
      viewModel.memoryPreferenceReflection?.trim() ||
      viewModel.subtitle.trim() ||
      null;
    return {
      title: "I remembered.",
      subtitle: recallSubtitle,
      watchingApplication: null,
    };
  }

  if (viewModel.beat === "understandingLook") {
    return {
      title: "Let me look.",
      subtitle: viewModel.subtitle.trim() || viewModel.applicationName,
      watchingApplication: viewModel.applicationName,
    };
  }

  if (viewModel.beat === "actionCanDo") {
    return {
      title: "I can do that.",
      subtitle: viewModel.subtitle.trim() || null,
      watchingApplication: viewModel.applicationName,
    };
  }

  if (viewModel.beat === "actionWantMeTo") {
    return {
      title: "Want me to?",
      subtitle: formatPermissionAction(viewModel.subtitle),
      watchingApplication: viewModel.applicationName,
    };
  }

  if (viewModel.beat === "targetUncertain") {
    return {
      title: viewModel.title.trim() || "Is that the right target?",
      subtitle: viewModel.subtitle.trim() || "Confirm on your Mac if that looks right.",
      watchingApplication: viewModel.applicationName,
    };
  }

  if (viewModel.beat === "understandingGotIt") {
    return {
      title: "Got it.",
      subtitle: viewModel.subtitle.trim() || viewModel.applicationName,
      watchingApplication: viewModel.applicationName,
    };
  }

  if (viewModel.beat === "answer") {
    return {
      title: viewModel.title,
      subtitle: viewModel.subtitle.trim() || null,
      watchingApplication: viewModel.applicationName,
    };
  }

  const { state, title, subtitle, applicationName, permissionActionLabel, interaction } = viewModel;

  switch (state) {
    case "idle":
      if (title === "Ready when you are.") {
        return {
          title,
          subtitle: subtitle.trim() || null,
          watchingApplication: resolveWatchingApplication(viewModel),
        };
      }
      return {
        title: hubAmbientIdleTitle,
        subtitle: subtitle.trim() || hubAmbientIdleSubtitle,
        watchingApplication: resolveWatchingApplication(viewModel),
      };

    case "aware": {
      if (title === "I didn't catch that.") {
        return {
          title: "I didn't catch that.",
          subtitle: subtitle.trim() || "Try again when you're ready.",
          watchingApplication: null,
        };
      }
      if (title === "Approve on your Mac" || title === "What should I do?" || title.startsWith("Point at something")) {
        return {
          title,
          subtitle: subtitle.trim() || null,
          watchingApplication: null,
        };
      }
      if (interaction === "pointer") {
        const targetLine = subtitle.trim();
        return {
          title: "I see what you're looking at.",
          subtitle: targetLine || applicationName,
          watchingApplication: applicationName,
        };
      }
      const application = applicationName ?? inferApplicationName(subtitle);
      return {
        title: application
          ? `I see you're working in ${application}.`
          : normalizeAwareTitle(title),
        subtitle: "looking at your screen",
        watchingApplication: application,
      };
    }

    case "listening":
      if (subtitle.includes("This tablet shows presence")) {
        return {
          title: "I'm listening...",
          subtitle,
          watchingApplication: applicationName,
        };
      }
      return {
        title: "I'm listening...",
        subtitle:
          interaction === "pointer"
            ? subtitle.trim() || applicationName || inferApplicationName(subtitle)
            : "Tell me what you need.",
        watchingApplication: applicationName,
      };

    case "speaking":
      return {
        title: "sharing the answer.",
        subtitle:
          interaction === "pointer"
            ? subtitle.trim() || applicationName
            : viewModel.voiceVisualOnly
              ? "Listen on your Mac."
              : subtitle.trim() || "Listen on your Mac.",
        watchingApplication: applicationName,
      };

    case "thinking":
      if (viewModel.verificationOutcome === "partial") {
        return {
          title: viewModel.title.trim() || "I completed the action, but I couldn't verify the result.",
          subtitle: pickResultSubtitle(subtitle) || "Check the result on your Mac.",
          watchingApplication: applicationName,
        };
      }
      if (title === "What should I teach you?") {
        return {
          title,
          subtitle: subtitle.trim() || null,
          watchingApplication: applicationName,
        };
      }
      if (viewModel.journeySteps !== null && viewModel.journeySteps.length > 0) {
        return {
          title: "thinking...",
          subtitle: pickThinkingSubtitle(subtitle),
          watchingApplication: applicationName,
        };
      }
      return {
        title: "thinking...",
        subtitle: pickThinkingSubtitle(subtitle),
        watchingApplication: applicationName,
      };

    case "acting":
      if (viewModel.journeySteps !== null && viewModel.journeySteps.length > 0) {
        return {
          title: "ACTING",
          subtitle: pickTaskSubtitle(subtitle, permissionActionLabel),
          watchingApplication: applicationName,
        };
      }
      return {
        title: "I've got it.",
        subtitle: pickTaskSubtitle(subtitle, permissionActionLabel),
        watchingApplication: applicationName,
      };

    case "verifying":
      if (viewModel.journeySteps !== null && viewModel.journeySteps.length > 0) {
        return {
          title: "CHECKING",
          subtitle: "Making sure it worked.",
          watchingApplication: applicationName,
        };
      }
      return {
        title: "I've got it.",
        subtitle: "Making sure it worked.",
        watchingApplication: applicationName,
      };

    case "success":
      return {
        title: "Done.",
        subtitle: pickResultSubtitle(subtitle) || "All set.",
        watchingApplication: applicationName,
      };

    case "permission": {
      const actionLine = permissionActionLabel ?? subtitle;
      return {
        title: interaction === "pointer" ? "Want me to fix it?" : "Want me to do that?",
        subtitle: formatPermissionAction(actionLine),
        watchingApplication: applicationName,
      };
    }

    case "error":
      return {
        title: "That didn't work.",
        subtitle: subtitle.trim() || "Something interrupted the action.",
        watchingApplication: null,
      };

    case "disconnected":
      return {
        title: "I can't reach Dexter.",
        subtitle: "Check the connection to your Mac.",
        watchingApplication: null,
      };

    default:
      return {
        title,
        subtitle: subtitle || null,
        watchingApplication: applicationName,
      };
  }
}

function resolveWatchingApplication(viewModel: DexterHubViewModel): string | null {
  const watchingName = viewModel.watchingApplicationName ?? viewModel.applicationName;
  if (!watchingName) return null;
  const trimmed = watchingName.trim();
  return trimmed.length > 0 ? trimmed.toUpperCase() : null;
}

function normalizeAwareTitle(incomingTitle: string): string {
  const trimmed = incomingTitle.trim();
  if (!trimmed || trimmed.toLowerCase() === "i see what you're working on.") {
    return "I see what you're working on.";
  }
  return trimmed;
}

function inferApplicationName(subtitle: string): string | null {
  const trimmed = subtitle.trim();
  if (!trimmed || trimmed.toLowerCase() === "looking at your screen") {
    return null;
  }
  return trimmed;
}

function pickThinkingSubtitle(incomingSubtitle: string): string {
  const normalized = incomingSubtitle.trim().toLowerCase();
  if (!normalized || GENERIC_THINKING_SUBTITLES.has(normalized)) {
    return "Putting the pieces together.";
  }
  return incomingSubtitle.trim();
}

function pickTaskSubtitle(incomingSubtitle: string, permissionActionLabel: string | null): string {
  const fromPermission = permissionActionLabel?.trim();
  if (fromPermission) {
    return formatTaskLine(fromPermission);
  }
  const trimmed = incomingSubtitle.trim();
  if (!trimmed) {
    return "Running the task";
  }
  return formatTaskLine(trimmed);
}

function pickResultSubtitle(incomingSubtitle: string): string | null {
  const trimmed = incomingSubtitle.trim();
  if (!trimmed || trimmed.toLowerCase() === "ready") {
    return null;
  }
  return trimmed;
}

function formatPermissionAction(line: string): string {
  const trimmed = line.trim();
  if (!trimmed) return "Open the target";
  if (trimmed.toLowerCase().startsWith("opening ")) {
    return `Open ${trimmed.slice("opening ".length)}`;
  }
  return trimmed;
}

function formatTaskLine(line: string): string {
  const trimmed = line.trim();
  if (!trimmed) return "Running the task";
  if (trimmed.toLowerCase().startsWith("opening ")) {
    const target = trimmed.slice("opening ".length);
    return `Opening ${target}`;
  }
  if (trimmed.toLowerCase().startsWith("running ")) {
    return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
  }
  const firstCharacter = trimmed.charAt(0);
  if (firstCharacter === firstCharacter.toLowerCase()) {
    return `${firstCharacter.toUpperCase()}${trimmed.slice(1)}`;
  }
  return trimmed;
}

export function companionShellStateClass(
  state: DexterState,
  beat: DexterHubViewModel["beat"],
  memoryPhase: DexterHubViewModel["memoryPhase"],
  teachingPhase: DexterHubViewModel["teachingPhase"],
  workflowSuggestionPhase: DexterHubViewModel["workflowSuggestionPhase"] = "none",
): string {
  if (teachingPhase !== "none") {
    return "hub-shell--companion-teaching";
  }
  if (memoryPhase !== "none") {
    return "hub-shell--companion-memory";
  }
  if (workflowSuggestionPhase !== "none") {
    return "hub-shell--companion-workflow";
  }
  if (beat === "answer") {
    return "hub-shell--companion-aware";
  }
  return `hub-shell--companion-${state}`;
}

function presentWorkflowSuggestionHub(viewModel: DexterHubViewModel): DexterHubPresentation {
  const routineName = viewModel.workflowRoutineName?.trim() || viewModel.subtitle.trim() || null;
  const trustLine = viewModel.workflowTrustPreview?.trim() || null;

  if (viewModel.workflowSuggestionPhase === "suggest") {
    return {
      title: "I noticed you do this a lot.",
      subtitle: "Want me to turn it into a routine?",
      watchingApplication: null,
    };
  }

  if (viewModel.workflowSuggestionPhase === "preview") {
    return {
      title: "I noticed something.",
      subtitle: trustLine ?? routineName,
      watchingApplication: null,
    };
  }

  return {
    title: routineName ?? "Your routine",
    subtitle: trustLine,
    watchingApplication: null,
  };
}

function presentTeachingHub(viewModel: DexterHubViewModel): DexterHubPresentation {
  const topicLine = viewModel.subtitle.trim() || viewModel.teachingStepSummary?.trim() || null;
  switch (viewModel.teachingPhase) {
    case "coaching":
      return {
        title: viewModel.title.trim() || "let's learn this.",
        subtitle: topicLine,
        watchingApplication: viewModel.applicationName,
      };
    case "yourTurn":
      return {
        title: "your turn.",
        subtitle: viewModel.teachingStepSummary?.trim() || topicLine || "Try it on your Mac.",
        watchingApplication: viewModel.applicationName,
      };
    case "affirmation":
      return {
        title: "that's it.",
        subtitle: viewModel.subtitle.trim() || "Nice work.",
        watchingApplication: viewModel.applicationName,
      };
    case "step":
    case "explaining":
    default:
      return {
        title: viewModel.title.trim() || "here's what's happening.",
        subtitle: viewModel.teachingStepSummary?.trim() || topicLine || "Follow along on your Mac.",
        watchingApplication: viewModel.applicationName,
      };
  }
}
