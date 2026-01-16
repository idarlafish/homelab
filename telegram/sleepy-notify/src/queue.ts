import { Queue, Worker } from "bullmq";
import { redisConnection } from "./redis"; // ← IMPORT THIS, not redis
import { bot } from "./bot";
import type { UserNotification } from "./types";

interface NotificationJob {
    userId: number;
    chatId: number;
    notification: UserNotification;
}

export const notificationQueue = new Queue<NotificationJob>("notifications", {
    connection: redisConnection, // ← Use redisConnection (plain object)
});

export const notificationWorker = new Worker<NotificationJob>(
    "notifications",
    async (job) => {
        const { userId, chatId, notification } = job.data;
        const today = new Date().toISOString().split("T")[0];

        if (notification.lastSentDate === today) {
            console.log(`Already sent notification ${notification.id} today`);
            return;
        }

        try {
            await bot.api.sendMessage({
                chat_id: chatId,
                text: notification.message,
                disable_notification: false,
            });

            console.log(`✅ Sent notification to ${chatId}: ${notification.message}`);

            // Update lastSentDate in Redis
            const { getUserConfig, setUserConfig } = await import("./redis");
            const config = await getUserConfig(userId);
            if (config) {
                const notif = config.notifications.find(n => n.id === notification.id);
                if (notif) {
                    notif.lastSentDate = today;
                    await setUserConfig(userId, config);
                }
            }

        } catch (error: any) {
            if (error?.description?.includes("blocked")) {
                console.log(`User ${chatId} blocked the bot`);
                throw new Error("USER_BLOCKED");
            }
            throw error;
        }
    },
    {
        connection: redisConnection,
        limiter: {
            max: 20,
            duration: 1000,
        },
        removeOnComplete: { count: 10 },
        removeOnFail: { count: 5 },
    }
);

notificationWorker.on("completed", (job) => {
    console.log(`Job ${job.id} completed`);
});

notificationWorker.on("failed", (job, err) => {
    console.error(`Job ${job?.id} failed:`, err.message);
});
