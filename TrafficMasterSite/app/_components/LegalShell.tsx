import Link from "next/link";
import type { ReactNode } from "react";

export function LegalShell({
  label,
  updated,
  children,
}: {
  label: string;
  updated: string;
  children: ReactNode;
}) {
  return (
    <div className="legal-shell">
      <header className="legal-header">
        <Link className="brand" href="/">
          <span className="brand-mark">TM</span>
          <span>TrafficMaster</span>
        </Link>
        <Link className="back-link" href="/">
          ← На главную
        </Link>
      </header>
      <div className="legal-layout">
        <aside className="legal-aside">
          <div className="eyebrow">{label}</div>
          <p>Обновлено: {updated}</p>
        </aside>
        <article className="legal-content">{children}</article>
      </div>
    </div>
  );
}
