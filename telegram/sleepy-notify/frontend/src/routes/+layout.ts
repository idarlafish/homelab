import { initTelegram } from "$lib/telegram";

export const ssr = false; // Disable SSR for Telegram WebApp
export const prerender = false;

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
