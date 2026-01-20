import type { WebApp } from '@twa-dev/types';

declare global {
	interface Window {
		Telegram?: {
			WebApp: WebApp;
		};
	}
}

export const tg = typeof window !== 'undefined' ? window.Telegram?.WebApp : null;

export function initTelegram(tg: WebApp) {
	console.log('Window object:', typeof window);
	console.log('Telegram object:', window.Telegram);
	console.log('WebApp object:', window.Telegram?.WebApp);

	if (tg) {
		console.log('Initializing Telegram WebApp...');
		tg.ready();
		tg.expand();
		console.log('Init data:', tg.initData);
	} else {
		console.error('Telegram WebApp not found!');
	}
}

export function getInitData(): string {
	return tg?.initData || '';
}

export function getTimezone(): string {
	return Intl.DateTimeFormat().resolvedOptions().timeZone;
}
