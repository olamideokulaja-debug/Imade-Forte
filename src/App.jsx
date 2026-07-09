import React, { useState } from 'react'

// FORTE COMPASS — Stage 1: Landing and brand
// Single-file app (src/App.jsx), Vite + React. Supabase auth and tenancy arrive in Stage 2.
// Brand tokens are held as CSS variables so a tenant can rebrand without a code change.
// Imade Forte tenant defaults: Navy #0E2240, Gold #B8924A, Lora.

const RUNGS = [
  { key: 'input', label: 'Input', note: 'resources committed', lit: false },
  { key: 'activity', label: 'Activity', note: 'actions taken', lit: false },
  { key: 'output', label: 'Output', note: 'things produced', lit: false },
  { key: 'outcome', label: 'Outcome', note: 'change delivered', lit: true },
]

const CAPABILITIES = [
  {
    title: 'Author',
    body: 'Draft objectives with an engine that coaches every key result toward an outcome, and asks for a reason before it lets a weaker measure through.',
  },
  {
    title: 'Track',
    body: 'Log progress on a cadence that fits the role, weekly for operations and monthly for leadership, against a baseline and a target.',
  },
  {
    title: 'Score',
    body: 'Auto-score against the house rubric, adjustable by a human and logged every time, banded green, amber or red.',
  },
  {
    title: 'Coach',
    body: 'See the next OKRs suggested for a role, and get a nudge on WhatsApp the moment a key result stalls.',
  },
]

function CompassMark() {
  return (
    <svg className="fc-mark" viewBox="0 0 48 48" role="img" aria-label="Forte Compass mark">
      <circle cx="24" cy="24" r="21" fill="none" stroke="var(--gold)" strokeWidth="1.5" opacity="0.55" />
      <circle cx="24" cy="24" r="15.5" fill="none" stroke="var(--gold)" strokeWidth="0.75" opacity="0.3" />
      {/* needle pointing up and to the right, toward the outcome */}
      <path d="M24 24 L35 13" stroke="var(--gold)" strokeWidth="2" strokeLinecap="round" />
      <path d="M24 24 L17 31" stroke="var(--parchment)" strokeWidth="1.5" strokeLinecap="round" opacity="0.55" />
      <circle cx="35" cy="13" r="2.6" fill="var(--gold)" />
      <circle cx="24" cy="24" r="1.6" fill="var(--parchment)" />
    </svg>
  )
}

export default function App() {
  const [revealed, setRevealed] = useState(false)

  return (
    <div className="fc-root">
      <style>{css}</style>

      <header className="fc-top">
        <a className="fc-brand" href="#top" aria-label="Forte Compass home">
          <CompassMark />
          <span className="fc-wordmark">
            Forte <em>Compass</em>
          </span>
        </a>
        <div className="fc-top-right">
          <span className="fc-tenant">Imade Forte Holdings</span>
          <button className="fc-btn fc-btn-ghost" onClick={() => setRevealed(true)}>
            Sign in
          </button>
        </div>
      </header>

      <main id="top" className="fc-hero">
        <div className="fc-hero-copy">
          <p className="fc-eyebrow">Office of the Chairman · OKR &amp; Performance</p>
          <h1 className="fc-headline">
            Manage to <span className="fc-gold">outcomes</span>.
          </h1>
          <p className="fc-sub">
            Forte Compass holds every team to the change it creates, not the hours it logs or the
            reports it files. Objectives are authored, tracked, scored and coached against outcomes,
            right across the group.
          </p>
          <div className="fc-cta-row">
            <button className="fc-btn fc-btn-gold" onClick={() => setRevealed(true)}>
              Preview the board
            </button>
            <a className="fc-link" href="#how">
              See how it works
            </a>
          </div>
        </div>

        {/* Signature: the outcome ladder. Only the top rung is lit. */}
        <aside className="fc-ladder" aria-label="From input to outcome">
          <ol className="fc-ladder-list">
            {RUNGS.map((r, i) => (
              <li key={r.key} className={`fc-rung ${r.lit ? 'is-lit' : ''}`}>
                <span className="fc-rung-index">{i + 1}</span>
                <span className="fc-rung-body">
                  <span className="fc-rung-label">{r.label}</span>
                  <span className="fc-rung-note">{r.note}</span>
                </span>
                {r.lit && <span className="fc-rung-flag">counts</span>}
              </li>
            ))}
          </ol>
          <p className="fc-ladder-caption">Effort climbs. Only the outcome is scored.</p>
        </aside>
      </main>

      {/* Live board teaser, blurred until sign-in */}
      <section className="fc-board-wrap" aria-label="Live group board preview">
        <div className={`fc-board ${revealed ? 'is-revealed' : ''}`}>
          <div className="fc-board-head">
            <span className="fc-board-cycle">May 2026 · Group</span>
            <span className="fc-board-live">Live</span>
          </div>
          <div className="fc-board-grid">
            <div className="fc-metric">
              <span className="fc-metric-value">62%</span>
              <span className="fc-metric-label">Outcome ratio</span>
            </div>
            <div className="fc-metric">
              <span className="fc-metric-value">7.3<span className="fc-metric-unit">/10</span></span>
              <span className="fc-metric-label">Weighted average</span>
            </div>
            <div className="fc-metric">
              <span className="fc-rag">
                <b className="fc-rag-g">9</b>
                <b className="fc-rag-a">6</b>
                <b className="fc-rag-r">0</b>
              </span>
              <span className="fc-metric-label">Green · Amber · Red</span>
            </div>
            <div className="fc-metric">
              <span className="fc-metric-value">15</span>
              <span className="fc-metric-label">Staff · 4 subsidiaries</span>
            </div>
          </div>
          {!revealed && (
            <div className="fc-board-lock">
              <svg viewBox="0 0 24 24" className="fc-lock" aria-hidden="true">
                <rect x="5" y="10" width="14" height="10" rx="2" fill="none" stroke="currentColor" strokeWidth="1.6" />
                <path d="M8 10V7a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" strokeWidth="1.6" />
              </svg>
              <p>Sign in to open the live board.</p>
              <button className="fc-btn fc-btn-gold" onClick={() => setRevealed(true)}>
                Sign in
              </button>
            </div>
          )}
        </div>
        {revealed && (
          <p className="fc-board-note">
            Preview only. Secure sign-in and the live board arrive in Stage 2.
          </p>
        )}
      </section>

      <section id="how" className="fc-how">
        <p className="fc-eyebrow fc-eyebrow-dark">What it does</p>
        <div className="fc-cap-grid">
          {CAPABILITIES.map((c, i) => (
            <article key={c.title} className="fc-cap">
              <span className="fc-cap-index">{String(i + 1).padStart(2, '0')}</span>
              <h3 className="fc-cap-title">{c.title}</h3>
              <p className="fc-cap-body">{c.body}</p>
            </article>
          ))}
        </div>
      </section>

      <footer className="fc-foot">
        <div className="fc-foot-left">
          <CompassMark />
          <span>Imade Forte Holdings Ltd. and Subsidiaries · Tenant one</span>
        </div>
        <span className="fc-foot-right">
          Forte Compass is tenant-aware and can be licensed to other firms.
        </span>
      </footer>
    </div>
  )
}

const css = `
:root {
  --navy: #0E2240;
  --navy-deep: #091A33;
  --navy-soft: #16304F;
  --gold: #B8924A;
  --gold-lit: #D8B266;
  --parchment: #EDE9E0;
  --muted: #93A0B4;
  --hairline: rgba(237, 233, 224, 0.14);
  --rag-g: #4FA07A;
  --rag-a: #C79A3E;
  --rag-r: #B65656;
}

* { box-sizing: border-box; }

.fc-root {
  margin: 0;
  min-height: 100vh;
  background: radial-gradient(120% 80% at 78% -10%, var(--navy-soft) 0%, var(--navy) 42%, var(--navy-deep) 100%);
  color: var(--parchment);
  font-family: 'Lora', Georgia, serif;
  -webkit-font-smoothing: antialiased;
  overflow-x: hidden;
}

.fc-btn {
  font-family: inherit;
  font-size: 0.95rem;
  letter-spacing: 0.01em;
  border-radius: 2px;
  padding: 0.62rem 1.25rem;
  cursor: pointer;
  border: 1px solid transparent;
  transition: background 160ms ease, color 160ms ease, border-color 160ms ease, transform 160ms ease;
}
.fc-btn:focus-visible { outline: 2px solid var(--gold-lit); outline-offset: 3px; }
.fc-btn-gold { background: var(--gold); color: var(--navy-deep); font-weight: 600; }
.fc-btn-gold:hover { background: var(--gold-lit); }
.fc-btn-ghost { background: transparent; color: var(--parchment); border-color: var(--hairline); }
.fc-btn-ghost:hover { border-color: var(--gold); color: var(--gold-lit); }

/* Top bar */
.fc-top {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.6rem clamp(1.25rem, 5vw, 5rem);
  border-bottom: 1px solid var(--hairline);
}
.fc-brand { display: flex; align-items: center; gap: 0.7rem; text-decoration: none; color: var(--parchment); }
.fc-mark { width: 30px; height: 30px; flex: none; }
.fc-wordmark { font-size: 1.18rem; letter-spacing: 0.14em; text-transform: uppercase; font-weight: 500; }
.fc-wordmark em { color: var(--gold); font-style: normal; }
.fc-top-right { display: flex; align-items: center; gap: 1.1rem; }
.fc-tenant { color: var(--muted); font-size: 0.9rem; letter-spacing: 0.02em; }

/* Hero */
.fc-hero {
  display: grid;
  grid-template-columns: 1.35fr 0.9fr;
  gap: clamp(2rem, 6vw, 5rem);
  align-items: center;
  padding: clamp(3rem, 9vw, 7rem) clamp(1.25rem, 5vw, 5rem) clamp(2rem, 5vw, 4rem);
  max-width: 1240px; margin: 0 auto;
}
.fc-eyebrow {
  color: var(--gold); font-size: 0.8rem; letter-spacing: 0.22em; text-transform: uppercase;
  margin: 0 0 1.3rem; font-weight: 600;
}
.fc-headline {
  font-size: clamp(2.7rem, 7vw, 5rem);
  line-height: 1.02; font-weight: 600; margin: 0 0 1.4rem; letter-spacing: -0.01em;
}
.fc-gold { color: var(--gold); font-style: italic; }
.fc-sub {
  font-size: clamp(1.05rem, 1.8vw, 1.3rem); line-height: 1.6; color: var(--parchment);
  max-width: 34ch; margin: 0 0 2rem; opacity: 0.92;
}
.fc-cta-row { display: flex; align-items: center; gap: 1.5rem; flex-wrap: wrap; }
.fc-link { color: var(--parchment); text-decoration: none; border-bottom: 1px solid var(--gold); padding-bottom: 2px; font-size: 0.98rem; }
.fc-link:hover { color: var(--gold-lit); }

/* Signature: outcome ladder */
.fc-ladder { border-left: 1px solid var(--hairline); padding-left: clamp(1.5rem, 3vw, 2.75rem); }
.fc-ladder-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 0.55rem; }
.fc-rung {
  display: flex; align-items: center; gap: 1rem;
  padding: 0.85rem 1rem; border: 1px solid var(--hairline); border-radius: 3px;
  opacity: 0.5; transition: opacity 220ms ease;
}
.fc-rung-index { font-size: 0.8rem; color: var(--muted); width: 1ch; }
.fc-rung-body { display: flex; flex-direction: column; }
.fc-rung-label { font-size: 1.15rem; font-weight: 500; }
.fc-rung-note { font-size: 0.82rem; color: var(--muted); letter-spacing: 0.01em; }
.fc-rung-flag {
  margin-left: auto; font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.14em;
  color: var(--navy-deep); background: var(--gold); padding: 0.22rem 0.6rem; border-radius: 2px; font-weight: 600;
}
.fc-rung.is-lit {
  opacity: 1; border-color: var(--gold);
  background: linear-gradient(90deg, rgba(184,146,74,0.16), rgba(184,146,74,0.03));
  box-shadow: 0 0 34px -14px var(--gold);
}
.fc-rung.is-lit .fc-rung-label { color: var(--gold-lit); }
.fc-rung.is-lit .fc-rung-index { color: var(--gold); }
.fc-ladder-caption { margin: 1.1rem 0 0; font-size: 0.85rem; color: var(--muted); font-style: italic; }

/* Live board */
.fc-board-wrap { max-width: 1240px; margin: 0 auto; padding: clamp(1rem, 3vw, 2rem) clamp(1.25rem, 5vw, 5rem) clamp(3rem, 6vw, 5rem); }
.fc-board {
  position: relative; border: 1px solid var(--hairline); border-radius: 6px;
  background: rgba(9, 26, 51, 0.6); padding: clamp(1.4rem, 3vw, 2.2rem);
  backdrop-filter: blur(2px);
}
.fc-board-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.6rem; }
.fc-board-cycle { color: var(--muted); font-size: 0.9rem; letter-spacing: 0.06em; text-transform: uppercase; }
.fc-board-live { color: var(--gold); font-size: 0.78rem; letter-spacing: 0.18em; text-transform: uppercase; }
.fc-board-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: clamp(1rem, 3vw, 2.5rem); transition: filter 260ms ease; }
.fc-board:not(.is-revealed) .fc-board-grid { filter: blur(9px); user-select: none; }
.fc-metric { display: flex; flex-direction: column; gap: 0.45rem; }
.fc-metric-value { font-size: clamp(2rem, 4vw, 2.9rem); font-weight: 600; line-height: 1; }
.fc-metric-unit { font-size: 1.1rem; color: var(--muted); font-weight: 400; }
.fc-metric-label { font-size: 0.82rem; color: var(--muted); letter-spacing: 0.03em; }
.fc-rag { display: flex; gap: 0.7rem; font-size: clamp(2rem, 4vw, 2.9rem); font-weight: 600; line-height: 1; }
.fc-rag-g { color: var(--rag-g); }
.fc-rag-a { color: var(--rag-a); }
.fc-rag-r { color: var(--rag-r); }
.fc-board-lock {
  position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 0.9rem; text-align: center; color: var(--parchment);
  background: radial-gradient(60% 60% at 50% 50%, rgba(9,26,51,0.35), rgba(9,26,51,0.72));
  border-radius: 6px;
}
.fc-board-lock p { margin: 0; color: var(--muted); font-size: 0.98rem; }
.fc-lock { width: 30px; height: 30px; color: var(--gold); }
.fc-board-note { margin: 1rem 0 0; color: var(--muted); font-size: 0.86rem; font-style: italic; }

/* How / capabilities */
.fc-how { background: var(--parchment); color: var(--navy-deep); padding: clamp(3rem, 7vw, 5.5rem) clamp(1.25rem, 5vw, 5rem); }
.fc-eyebrow-dark { color: var(--gold); }
.fc-cap-grid { max-width: 1240px; margin: 1.6rem auto 0; display: grid; grid-template-columns: repeat(4, 1fr); gap: clamp(1.5rem, 3vw, 3rem); }
.fc-cap { border-top: 2px solid var(--navy); padding-top: 1.1rem; }
.fc-cap-index { font-size: 0.82rem; color: var(--gold); letter-spacing: 0.1em; font-weight: 600; }
.fc-cap-title { font-size: 1.4rem; font-weight: 600; margin: 0.4rem 0 0.7rem; color: var(--navy-deep); }
.fc-cap-body { font-size: 0.98rem; line-height: 1.62; color: #3a4658; margin: 0; }

/* Footer */
.fc-foot {
  display: flex; align-items: center; justify-content: space-between; gap: 1.5rem; flex-wrap: wrap;
  padding: 1.8rem clamp(1.25rem, 5vw, 5rem); border-top: 1px solid var(--hairline);
  color: var(--muted); font-size: 0.88rem;
}
.fc-foot-left { display: flex; align-items: center; gap: 0.8rem; }
.fc-foot-left .fc-mark { width: 24px; height: 24px; opacity: 0.85; }

/* Responsive */
@media (max-width: 900px) {
  .fc-hero { grid-template-columns: 1fr; }
  .fc-ladder { border-left: none; border-top: 1px solid var(--hairline); padding-left: 0; padding-top: 2rem; }
  .fc-board-grid { grid-template-columns: repeat(2, 1fr); gap: 1.6rem; }
  .fc-cap-grid { grid-template-columns: repeat(2, 1fr); }
}
@media (max-width: 560px) {
  .fc-top { flex-wrap: wrap; gap: 0.8rem; }
  .fc-tenant { display: none; }
  .fc-board-grid { grid-template-columns: 1fr 1fr; }
  .fc-cap-grid { grid-template-columns: 1fr; }
  .fc-foot { flex-direction: column; align-items: flex-start; }
}

@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; }
}
`
