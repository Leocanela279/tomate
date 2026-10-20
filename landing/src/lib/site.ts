export const REPO_URL = 'https://github.com/Leocanela279/tomate';
export const RELEASES_URL = `${REPO_URL}/releases`;
/** Always the newest release: the workflow uploads the disk image with this fixed name. */
export const DMG_URL = `${RELEASES_URL}/latest/download/Tomate.dmg`;
export const AUTHOR = 'Leandro Canela';
export const AUTHOR_URL = 'https://github.com/Leocanela279';

/** Pixel size of the window captures in public/media (880x680 pt at 2x). */
export const SHOT = { width: 1760, height: 1360 };

/** The app's three tabs, in order, with what each screenshot shows. */
export const SCREENS = [
  {
    id: 'timer',
    tab: 'Temporizador',
    title: 'Temporizador',
    text: 'Elige tema y duración y, si es largo, pártelo en dos con un descanso a mitad. El tomate se vacía mientras estudias.',
    alt: 'el dial con 45:00 y el plan de 90 minutos en dos bloques con 15 minutos de descanso',
  },
  {
    id: 'schedule',
    tab: 'Programados',
    badge: 3,
    title: 'Programados',
    text: 'Deja tus sesiones preparadas. A su hora te llega un aviso con Empezar y Rechazar, y nunca se pisan dos.',
    alt: 'la lista de pomodoros programados para mañana y pasado',
  },
  {
    id: 'history',
    tab: 'Historial',
    title: 'Historial',
    text: 'Lo que llevas estudiado hoy, la gráfica de los últimos siete días y cada sesión con su hora y duración.',
    alt: 'el resumen de hoy, la gráfica semanal y las sesiones del día',
  },
] as const;

/** Paths inside /public, prefixed with the base path (empty on usetomate.com). */
export const asset = (path: string) => `${import.meta.env.BASE_URL.replace(/\/$/, '')}/${path}`;
