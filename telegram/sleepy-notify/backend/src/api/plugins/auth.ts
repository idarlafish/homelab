import { Elysia } from 'elysia';
import { validateInitData } from '../utils/telegram-auth';

export const telegramAuth = new Elysia({ name: 'telegram-auth' })
    .derive({ as: 'global' }, ({ request }) => ({
        getTelegramUser: () => {
            const authHeader = request.headers.get('authorization');

            return {
                id: 671615920,
            }

            if (!authHeader?.startsWith('tma ')) {
                throw new Error('Missing auth');
            }

            // const initData = authHeader.substring(4);
            // return validateInitData(initData);
        }
    }));
