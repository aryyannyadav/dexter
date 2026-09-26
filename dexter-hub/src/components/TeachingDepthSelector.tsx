import type { DexterHubTeachingDepth } from "../types/dexterEvents";

const DEPTH_OPTIONS: { id: DexterHubTeachingDepth; label: string }[] = [
  { id: "eli5", label: "ELI5" },
  { id: "simple", label: "Simple" },
  { id: "normal", label: "Normal" },
  { id: "technical", label: "Technical" },
  { id: "expert", label: "Expert" },
];

type TeachingDepthSelectorProps = {
  selectedDepth: DexterHubTeachingDepth;
  onSelectDepth: (depth: DexterHubTeachingDepth) => void;
};

export function TeachingDepthSelector({ selectedDepth, onSelectDepth }: TeachingDepthSelectorProps) {
  return (
    <div className="hub-teaching-depth" role="group" aria-label="Explanation depth">
      {DEPTH_OPTIONS.map((option) => (
        <button
          key={option.id}
          type="button"
          className={`hub-teaching-depth__pill${selectedDepth === option.id ? " hub-teaching-depth__pill--active" : ""}`}
          onPointerUp={() => onSelectDepth(option.id)}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}
