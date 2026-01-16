import { notificationQueue } from "./queue";
import { getUserConfig } from "./redis";

export async function scheduleUserNotifications(userId: number) {
    const config = await getUserConfig(userId);

    // Remove existing jobs...

    if (!config || !config.enabled || config.notifications.length === 0) {
        return;
    }

    for (const notif of config.notifications) {
        const [hours, minutes] = notif.time.split(":").map(Number);
        const cronPattern = `${minutes} ${hours} * * *`;

        await notificationQueue.add(
            "sendNotification",
            { userId, chatId: config.chatId, notification: notif },
            {
                repeat: {
                    pattern: cronPattern,
                    tz: notif.timezone,
                },
                jobId: `user:${userId}:notif:${notif.id}`,
                removeOnComplete: 10,
                removeOnFail: 5,
            }
        );

        console.log(`📅 Scheduled ${notif.time} ${notif.timezone} for user ${userId}`);
    }
}

