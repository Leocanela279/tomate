// Everything the page does: theme switch, the sliding tab pills, the screenshots that turn like a
// card and play by themselves, and the fade-in of sections. No framework; a few listeners.

const root = document.documentElement;
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const THEME_KEY = 'tomate.theme';

type Theme = 'tomato' | 'dark';

// ---------- Theme ----------

const currentTheme = (): Theme => (root.dataset.theme === 'dark' ? 'dark' : 'tomato');

function applyTheme(theme: Theme) {
  if (theme === 'dark') root.dataset.theme = 'dark';
  else delete root.dataset.theme;
  try {
    localStorage.setItem(THEME_KEY, theme);
  } catch {}
  syncThemeControls();
}

function syncThemeControls() {
  const dark = currentTheme() === 'dark';
  const label = dark ? 'Cambiar a modo tomate' : 'Cambiar a modo oscuro';
  for (const button of document.querySelectorAll<HTMLElement>('[data-theme-toggle]')) {
    button.setAttribute('aria-label', label);
    button.title = label;
  }
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', dark ? '#211213' : '#bf2620');
}

/** Replays the button's little bounce, like .symbolEffect(.bounce). */
function bounce(button: HTMLElement) {
  button.classList.remove('is-bouncing');
  void button.offsetWidth;
  button.classList.add('is-bouncing');
}

let switching = false;

/** The new look grows as a soft-edged circle from the button, as in the app (ThemeSwitch.swift). */
function toggleTheme(from: HTMLElement) {
  const next: Theme = currentTheme() === 'dark' ? 'tomato' : 'dark';

  if (!document.startViewTransition || reduceMotion.matches || switching) {
    applyTheme(next);
    bounce(from);
    return;
  }

  const box = from.getBoundingClientRect();
  const x = box.left + box.width / 2;
  const y = box.top + box.height / 2;
  // The circle is opaque up to 80% of its radius: it starts already covering the button,
  // so the change is visible from the first frame, and ends past the farthest corner.
  const start = box.width / 2 / 0.8;
  const end = (Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y)) / 0.8) * 1.02;

  root.style.setProperty('--reveal-x', `${x}px`);
  root.style.setProperty('--reveal-y', `${y}px`);
  root.style.setProperty('--reveal-start', `${start}px`);
  root.classList.add('theme-swap');
  switching = true;

  const transition = document.startViewTransition(() => applyTheme(next));
  transition.ready
    .then(() => {
      bounce(from);
      root.animate(
        { '--reveal': [`${start}px`, `${end}px`] } as PropertyIndexedKeyframes,
        {
          duration: 620,
          // Leaves the button fast and slows down as it fills the page.
          easing: 'cubic-bezier(0.3, 0.7, 0.25, 1)',
          fill: 'forwards',
          pseudoElement: '::view-transition-new(root)',
        },
      );
    })
    .catch(() => bounce(from));
  transition.finished.finally(() => {
    root.classList.remove('theme-swap');
    switching = false;
  });
}

/** The screenshot on show exists in both looks; fetch the other one before the click needs it. */
function preloadOtherLook() {
  const other = currentTheme() === 'dark' ? 'only-tomato' : 'only-dark';
  for (const img of document.querySelectorAll<HTMLImageElement>(`.shot:not(.is-off) img.${other}`)) img.loading = 'eager';
}

for (const button of document.querySelectorAll<HTMLElement>('[data-theme-toggle]')) {
  button.addEventListener('click', () => toggleTheme(button));
  button.addEventListener('pointerenter', preloadOtherLook);
  button.addEventListener('focus', preloadOtherLook);
}
syncThemeControls();

// ---------- Sliding pill (tab bars) ----------

/** Puts the glass pill of a tab bar under its selected item. */
function placePill(bar: HTMLElement, animate = true) {
  const pill = bar.querySelector<HTMLElement>('[data-pill]');
  const selected = bar.querySelector<HTMLElement>('[aria-selected="true"], [aria-current="location"]');
  if (!pill || !selected) return;
  if (!animate) pill.style.transition = 'none';
  pill.style.width = `${selected.offsetWidth}px`;
  pill.style.transform = `translateX(${selected.offsetLeft}px)`;
  pill.style.opacity = '1';
  if (!animate) {
    void pill.offsetWidth;
    pill.style.transition = '';
  }
}

const bars = [...document.querySelectorAll<HTMLElement>('[data-tabbar]')];
const placeAll = (animate: boolean) => bars.forEach((bar) => placePill(bar, animate));
placeAll(false);
document.fonts?.ready.then(() => placeAll(false));
new ResizeObserver(() => placeAll(false)).observe(document.body);

// ---------- Header navigation: follows the section in view ----------

const nav = document.querySelector<HTMLElement>('[data-nav]');
const navLinks = nav ? [...nav.querySelectorAll<HTMLAnchorElement>('a[href^="#"]')] : [];
let followScroll = true;

function setCurrent(id: string) {
  if (!nav) return;
  for (const link of navLinks) {
    const on = link.hash === `#${id}`;
    if (on) link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  }
  placePill(nav);
}

for (const link of navLinks) {
  link.addEventListener('click', () => {
    // Jump the pill straight to the destination instead of passing through every section.
    followScroll = false;
    setCurrent(link.hash.slice(1));
    const resume = () => (followScroll = true);
    if ('onscrollend' in window) window.addEventListener('scrollend', resume, { once: true });
    else setTimeout(resume, 900);
  });
}

const sections = navLinks
  .map((link) => document.getElementById(link.hash.slice(1)))
  .filter((section): section is HTMLElement => section !== null);

const spy = new IntersectionObserver(
  (entries) => {
    if (!followScroll) return;
    const visible = entries.filter((entry) => entry.isIntersecting);
    if (visible.length) setCurrent(visible[visible.length - 1].target.id);
  },
  { rootMargin: '-45% 0px -50% 0px' },
);
sections.forEach((section) => spy.observe(section));

// ---------- Screens: the app's tab bar over real screenshots, turning like a card ----------

const ADVANCE_MS = 4200;

/** Resolves once the screenshot shown in the current look is ready to paint (or after a short wait). */
function imageReady(panel: HTMLElement) {
  const img = panel.querySelector<HTMLImageElement>(currentTheme() === 'dark' ? 'img.only-dark' : 'img.only-tomato');
  if (!img) return Promise.resolve();
  img.loading = 'eager';
  const ready = img.complete && img.naturalWidth ? Promise.resolve() : img.decode().catch(() => {});
  return Promise.race([ready, new Promise((resolve) => setTimeout(resolve, 700))]);
}

for (const showcase of document.querySelectorAll<HTMLElement>('[data-showcase]')) {
  const bar = showcase.querySelector<HTMLElement>('[role="tablist"]')!;
  const tabs = [...bar.querySelectorAll<HTMLButtonElement>('[role="tab"]')];
  const panels = tabs.map((tab) => document.getElementById(tab.getAttribute('aria-controls') ?? '')!);
  const playButton = showcase.querySelector<HTMLButtonElement>('[data-play]')!;
  const ring = showcase.querySelector<SVGCircleElement>('[data-ring]')!;
  let current = Math.max(0, tabs.findIndex((tab) => tab.getAttribute('aria-selected') === 'true'));

  // Every screen stays in the same grid cell, so the height never jumps; only one is visible.
  // `shown` is that one; `current` is the selected tab, which leads it during a turn.
  let shown = current;
  const show = (index: number) => {
    shown = index;
    panels.forEach((panel, i) => {
      panel.hidden = false;
      panel.classList.toggle('is-off', i !== index);
      panel.inert = i !== index;
    });
  };
  show(current);

  // ----- The turn -----

  let turn = 0; // Bumped on every change, so an older, slower turn never finishes on top of a newer one.
  const running: Animation[] = [];
  const stopRunning = () => running.splice(0).forEach((animation) => animation.cancel());

  async function goTo(index: number, direction: 1 | -1) {
    const next = (index + tabs.length) % tabs.length;
    if (next === current) return;
    const from = panels[shown];
    const to = panels[next];
    current = next;
    const mine = ++turn;

    tabs.forEach((tab, i) => {
      const on = i === next;
      tab.setAttribute('aria-selected', String(on));
      tab.tabIndex = on ? 0 : -1;
    });
    placePill(bar);
    stopRunning();

    const ready = imageReady(to);

    if (reduceMotion.matches) {
      // No turning: a short cross-fade.
      await ready;
      if (mine !== turn) return;
      show(next);
      running.push(to.animate({ opacity: [0, 1] }, { duration: 220, easing: 'ease-out' }));
      return;
    }

    const fromCard = from.querySelector<HTMLElement>('[data-card]')!;
    const toCard = to.querySelector<HTMLElement>('[data-card]')!;
    const fromCaption = from.querySelector<HTMLElement>('[data-caption]')!;
    const toCaption = to.querySelector<HTMLElement>('[data-caption]')!;

    // First half, straight away: the window turns away until it is edge-on, smaller and in shadow.
    // The next screenshot finishes loading meanwhile, if it had not already.
    const away = 92 * direction;
    const out = fromCard.animate(
      [
        { transform: 'rotateY(0deg) scale(1)', filter: 'brightness(1)' },
        { transform: `rotateY(${-away}deg) scale(0.92)`, filter: 'brightness(0.55)' },
      ],
      { duration: 280, easing: 'cubic-bezier(0.45, 0, 0.8, 0.4)', fill: 'forwards' },
    );
    running.push(out, fromCaption.animate({ opacity: [1, 0] }, { duration: 180, easing: 'ease-in', fill: 'forwards' }));
    try {
      await Promise.all([out.finished, ready]);
    } catch {
      return; // Cancelled by a newer turn.
    }
    if (mine !== turn) return;

    // Second half: the next screen comes round from the other side and settles with a slight spring.
    show(next);
    stopRunning();
    running.push(
      toCard.animate(
        [
          { transform: `rotateY(${away}deg) scale(0.92)`, filter: 'brightness(0.55)' },
          { transform: 'rotateY(0deg) scale(1)', filter: 'brightness(1)' },
        ],
        { duration: 620, easing: 'linear(0, 0.157, 0.438, 0.68, 0.849, 0.951, 1.003, 1.022, 1.022, 1.014, 1.006, 1.001, 1)' },
      ),
      toCaption.animate(
        { opacity: [0, 1], transform: ['translateY(6px)', 'none'] },
        { duration: 360, delay: 120, easing: 'ease-out', fill: 'backwards' },
      ),
    );
  }

  // ----- Playing by itself -----
  // `playing` is the visitor's choice; waiting() holds it anyway while the pointer or the focus
  // is on it, while it is off screen and while the tab is in the background.

  let playing = !reduceMotion.matches;
  let hover = false;
  let focusInside = false;
  let onScreen = false;
  let timer: Animation | undefined;

  const waiting = () => hover || focusInside || !onScreen || document.hidden;

  function startTimer() {
    timer?.cancel();
    timer = ring.animate({ strokeDashoffset: [100, 0] }, { duration: ADVANCE_MS, easing: 'linear', fill: 'forwards' });
    timer.onfinish = () => {
      void goTo(current + 1, 1);
      startTimer();
      sync();
    };
  }

  function sync() {
    playButton.classList.toggle('is-paused', !playing);
    const label = playing ? 'Pausar la demostración' : 'Reproducir la demostración';
    playButton.setAttribute('aria-label', label);
    playButton.title = label;
    if (!playing) {
      timer?.cancel();
      timer = undefined;
      return;
    }
    if (!timer) startTimer();
    if (waiting()) timer?.pause();
    else timer?.play();
  }

  playButton.hidden = false;
  playButton.addEventListener('click', () => {
    playing = !playing;
    if (playing) void goTo(current + 1, 1); // Something happens right away when resuming.
    sync();
  });

  showcase.addEventListener('pointerenter', (event) => {
    if (event.pointerType !== 'mouse') return;
    hover = true;
    sync();
  });
  showcase.addEventListener('pointerleave', () => {
    hover = false;
    sync();
  });
  showcase.addEventListener('focusin', () => {
    focusInside = true;
    sync();
  });
  showcase.addEventListener('focusout', (event) => {
    if (showcase.contains(event.relatedTarget as Node | null)) return;
    focusInside = false;
    sync();
  });
  new IntersectionObserver(
    ([entry]) => {
      onScreen = entry.isIntersecting;
      sync();
    },
    { threshold: 0.35 },
  ).observe(showcase);
  document.addEventListener('visibilitychange', sync);

  // Choosing a screen yourself stops the show; the button resumes it.
  const choose = (index: number, direction: 1 | -1, focus: boolean) => {
    playing = false;
    sync();
    void goTo(index, direction);
    if (focus) tabs[(index + tabs.length) % tabs.length].focus();
  };

  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => choose(index, index > current ? 1 : -1, false));
    tab.addEventListener('keydown', (event) => {
      const moves: Record<string, [number, 1 | -1]> = {
        ArrowRight: [index + 1, 1],
        ArrowLeft: [index - 1, -1],
        Home: [0, -1],
        End: [tabs.length - 1, 1],
      };
      const move = moves[event.key];
      if (!move) return;
      event.preventDefault();
      choose(move[0], move[1], true);
    });
  });

  sync();

  // Once the page has settled, fetch the other screens in the current look, so the first turn
  // never waits on the network.
  const warm = () => panels.forEach((panel) => void imageReady(panel));
  const idle = (callback: () => void) =>
    'requestIdleCallback' in window ? requestIdleCallback(callback, { timeout: 2500 }) : setTimeout(callback, 1200);
  if (document.readyState === 'complete') idle(warm);
  else addEventListener('load', () => idle(warm), { once: true });
}

// ---------- Sections fade up the first time they appear ----------

const reveal = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('is-visible');
      reveal.unobserve(entry.target);
    }
  },
  { rootMargin: '0px 0px -8% 0px' },
);
document.querySelectorAll('.reveal-up').forEach((element) => reveal.observe(element));

// ---------- Copy buttons ----------

/** Swaps the label with a short unblur, so the new word settles in instead of popping. */
function setLabel(label: HTMLElement | null, text: string) {
  if (!label || label.textContent === text) return;
  label.textContent = text;
  label.animate({ opacity: [0.3, 1], filter: ['blur(3px)', 'blur(0)'] }, { duration: 220, easing: 'ease-out' });
}

for (const button of document.querySelectorAll<HTMLButtonElement>('[data-copy]')) {
  const label = button.querySelector<HTMLElement>('[data-copy-label]');
  let reset: ReturnType<typeof setTimeout> | undefined;
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copy ?? '');
      clearTimeout(reset); // Another click restarts the wait instead of flipping back early.
      button.classList.add('is-copied');
      setLabel(label, 'Copiado');
      reset = setTimeout(() => {
        button.classList.remove('is-copied');
        setLabel(label, 'Copiar');
      }, 1600);
    } catch {}
  });
}
