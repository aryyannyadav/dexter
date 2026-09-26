type MemoryMomentActionsProps = {
  memoryRecordId: string;
  onViewMemory: (memoryRecordId: string) => void;
  onForgetMemory: (memoryRecordId: string) => void;
};

export function MemoryMomentActions({
  memoryRecordId,
  onViewMemory,
  onForgetMemory,
}: MemoryMomentActionsProps) {
  return (
    <div className="hub-memory-actions" role="group" aria-label="Memory actions">
      <button
        type="button"
        className="hub-memory-actions__button"
        onClick={() => onViewMemory(memoryRecordId)}
      >
        View
      </button>
      <button
        type="button"
        className="hub-memory-actions__button hub-memory-actions__button--quiet"
        onClick={() => onForgetMemory(memoryRecordId)}
      >
        Forget
      </button>
    </div>
  );
}
