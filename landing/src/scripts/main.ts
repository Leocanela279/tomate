// Everything the page does: theme switch, the sliding tab pills, the screenshots tabs,
// the self-playing screenshots and the fade-in of sections. No framework; a few listeners.

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

/** The new look grows as a soft-edged circle from the button, as in the app (ThemeSwitch.swift). */
function toggleTheme(from: HTMLElement) {
  const next: Theme = currentTheme() === 'dark' ? 'tomato' : 'dark';
  from.classList.remove('is-bouncing');
  void from.offsetWidth;
  from.classList.add('is-bouncing');

  if (!document.startViewTransition || reduceMotion.matches) {
    applyTheme(next);
    return;
  }

  const box = from.getBoundingClientRect();
  const x = box.left + box.width / 2;
  const y = box.top + box.height / 2;
  // Opaque up to 80% of the radius, so that part must reach the farthest corner.
  const farthest = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
  const radius = (farthest / 0.8) * 1.02;

  root.style.setProperty('--reveal-x', `${x}px`);
  root.style.setProperty('--reveal-y', `${y}px`);

  const transition = document.startViewTransition(() => applyTheme(next));
  transition.ready.then(() => {
    root.animate(
      { '--reveal': ['0px', `${radius}px`] } as PropertyIndexedKeyframes,
      { duration: 750, easing: 'ease-in-out', pseudoElement: '::view-transition-new(root)' },
    );
  });
}

for (const button of document.querySelectorAll<HTMLElement>('[data-theme-toggle]')) {
  button.addEventListener('click', () => toggleTheme(button));
}
syncThemeControls();

// ---------- Sliding pill (tab bars) ----------

/** Puts the glass pill of a tab bar under its selected item. */
function placePill(bar: HTMLElement, animate = true) {
  const pill = bar.querySelector<HTMLElement>('[data-pill]');
  const selected = bar.querySelector<HTMLElement>('[aria-selected="true"], [aria-current="true"]');
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
    if (on) link.setAttribute('aria-current', 'true');
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

// ---------- Screens: the app's tab switch, with real screenshots ----------

for (const bar of document.querySelectorAll<HTMLElement>('[data-tabbar][role="tablist"]')) {
  const tabs = [...bar.querySelectorAll<HTMLButtonElement>('[role="tab"]')];
  let current = Math.max(0, tabs.findIndex((tab) => tab.getAttribute('aria-selected') === 'true'));

  const select = (index: number, focus = false) => {
    current = (index + tabs.length) % tabs.length;
    tabs.forEach((tab, i) => {
      const on = i === current;
      tab.setAttribute('aria-selected', String(on));
      tab.tabIndex = on ? 0 : -1;
      const panel = document.getElementById(tab.getAttribute('aria-controls') ?? '');
      if (!panel) return;
      // The old screen leaves at once and the new one fades in (MainView.screenChange).
      panel.hidden = !on;
      if (on) {
        panel.classList.remove('screen-in');
        void panel.offsetWidth;
        panel.classList.add('screen-in');
      }
    });
    if (focus) tabs[current].focus();
    placePill(bar);
  };

  // Plays by itself like a GIF while it is on screen. Touching it stops that for good.
  let timer: number | undefined;
  let visible = false;
  let handedOver = false;
  const schedule = () => {
    clearTimeout(timer);
    if (handedOver || !visible || document.hidden || reduceMotion.matches || !bar.hasAttribute('data-autoplay')) return;
    timer = window.setTimeout(() => {
      select(current + 1);
      schedule();
    }, 3200);
  };
  const handOver = () => {
    handedOver = true;
    clearTimeout(timer);
  };

  new IntersectionObserver(([entry]) => {
    visible = entry.isIntersecting;
    schedule();
  }, { threshold: 0.35 }).observe(bar.parentElement?.parentElement ?? bar);
  document.addEventListener('visibilitychange', schedule);

  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => {
      handOver();
      select(index);
    });
    tab.addEventListener('keydown', (event) => {
      const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0;
      if (!step) return;
      event.preventDefault();
      handOver();
      select(index + step, true);
    });
  });
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

for (const button of document.querySelectorAll<HTMLButtonElement>('[data-copy]')) {
  const label = button.querySelector('[data-copy-label]');
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copy ?? '');
      if (label) {
        label.textContent = 'Copiado';
        setTimeout(() => (label.textContent = 'Copiar'), 1600);
      }
    } catch {}
  });
}
