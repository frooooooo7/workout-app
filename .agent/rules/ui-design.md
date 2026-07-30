# UI/UX & Animation Design Rules

Przy **KAŻDEJ** zmianie, modyfikacji lub tworzeniu elementów interfejsu (UI/UX), komponentów, ekranów oraz animacji w tym projekcie, agent **MUST** bezwzględnie stosować wytyczne z dwóch skilli projektowych:

---

## 1. Emil Kowalski Design Engineering (`emil-design-eng`)
- **Responsive Press Feedback**: Każdy element klikalny/przycisk musi reagować na dotknięcie subtelnym przeskalowaniem (`scale(0.96-0.98)` / spring animation).
- **Custom Easing & Timing**: Wszystkie animacje UI nie mogą przekraczać **200ms** dla reakcji na akcje i muszą używać naturalnego wygaszania (`ease-out` / `easeOutCubic`).
- **Optical Alignment & Symmetry**: Wszystkie przyciski akcji w tym samym wierszu muszą mieć **identyczną wysokość**, spójny promień zaokrąglenia (`borderRadius`) i symetryczne ułożenie ikon.
- **Unseen Details**: Dbałość o precyzyjne mikroszczegóły, brak wiszących asymetrycznych odstępów pionowych i płynne stany ładowania (skeleton shimmer).

---

## 2. Anti-Slop Frontend Taste (`design-taste-frontend`)
- **Design Read**: Przed rozpoczęciem zmian wizualnych agent przedstawia zwięzły opis kierunku estetycznego (*Design Read*).
- **High-End Dark Mode Aesthetics**: Wykorzystanie matowych gradientów Linear/Apple, głębokiego tła (`surface`), rozświetlonych ramek (`border-alpha`) i akcentowanych cieni.
- **Micro-Typography**: Przejrzysta hierarchia – nagłówki majuskułą z szerokim `letterSpacing` dla etykiet (`text-[10px]`, `tracking-widest`) oraz wyraziste cyfry statystyk.
- **Status Badges & Visual Anchors**: Zamiast surowego tekstu – eleganckie pigułki statusowe, akcenty z żywą kropką statusu oraz ikony w dopracowanych kontenerach.
