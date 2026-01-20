import { initTelegram } from '$lib/telegram';

export const prerender = false;
export const ssr = false;
export const trailingSlash = 'always';

export async function load() {
	if (typeof window !== 'undefined' && window.Telegram?.WebApp) {
		const tg = window.Telegram.WebApp;
		initTelegram(tg);

		// Ensure initData is available before pages load
		return {
			initData: tg.initData
		};
	}

	return { initData: '' };
}
