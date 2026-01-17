import crypto from 'crypto';
import { config } from '../../config';

export interface TelegramUser {
    id: number;
    first_name: string;
    last_name?: string;
    username?: string;
}

export function validateInitData(initData: string): TelegramUser {
    const urlParams = new URLSearchParams(initData);
    const hash = urlParams.get('hash');

    if (!hash) throw new Error('Missing hash');

    urlParams.delete('hash');

    const dataCheckString = Array.from(urlParams.entries())
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, value]) => `${key}=${value}`)
        .join('\n');

    const secretKey = crypto
        .createHmac('sha256', 'WebAppData')
        .update(config.BOT_TOKEN)
        .digest();

    const expectedHash = crypto
        .createHmac('sha256', secretKey)
        .update(dataCheckString)
        .digest('hex');

    if (hash !== expectedHash) {
        throw new Error('Invalid signature');
    }

    const authDate = parseInt(urlParams.get('auth_date') || '0');
    if (Math.floor(Date.now() / 1000) - authDate > 1200) {
        throw new Error('Expired');
    }

    const userJson = urlParams.get('user');
    if (!userJson) throw new Error('No user data');

    return JSON.parse(userJson);
}
