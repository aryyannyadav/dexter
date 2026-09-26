type IdentityCardProps = {
  onClose: () => void;
};

export function IdentityCard({ onClose }: IdentityCardProps) {
  return (
    <>
      <button type="button" className="hub-scrim" aria-label="Close identity card" onPointerUp={onClose} />
      <div className="hub-identity-card" role="dialog" aria-labelledby="dexter-identity-title">
        <button type="button" className="hub-identity-close" aria-label="Close" onPointerUp={onClose}>
          ×
        </button>
        <h3 id="dexter-identity-title">DEXTER</h3>
        <p>Your personal computer companion.</p>
        <div className="hub-identity-tags">
          {["SEE", "TEACH", "ACT", "VERIFY", "REMEMBER"].map((tag) => (
            <span key={tag}>{tag}</span>
          ))}
        </div>
      </div>
    </>
  );
}
