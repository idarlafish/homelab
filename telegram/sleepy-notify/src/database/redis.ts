import Redis from "ioredis";
import { config } from "../config";
import type { UserScheduleConfig } from "../types";

// Regular Redis instance for direct operations
export const redis = new Redis({
    host: config.REDIS_HOST,
    port: config.REDIS_PORT,
    password: config.REDIS_PASSWORD || undefined,
    maxRetriesPerRequest: null,
});

// Connection options for BullMQ
export const redisConnection = {
    host: config.REDIS_HOST,
    port: config.REDIS_PORT,
    password: config.REDIS_PASSWORD || undefined,
};

export const userConfigKey = (userId: number) => `user:${userId}:schedule`;

export async function getUserConfig(userId: number): Promise<UserScheduleConfig | null> {
    const raw = await redis.get(userConfigKey(userId));
    return raw ? (JSON.parse(raw) as UserScheduleConfig) : null;
}

export async function setUserConfig(userId: number, config: UserScheduleConfig): Promise<void> {
    await redis.set(userConfigKey(userId), JSON.stringify(config));
}

export async function deleteUserConfig(userId: number): Promise<void> {
    await redis.del(userConfigKey(userId));
}

export async function getAllUserIds(): Promise<number[]> {
    const keys = await redis.keys("user:*:schedule");
    return keys.map((key) => {
        const match = key.match(/user:(\d+):schedule/);
        return match ? Number.parseInt(match[1] ?? '') : null;
    }).filter((id): id is number => id !== null);
}
