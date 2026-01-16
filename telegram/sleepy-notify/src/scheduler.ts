import { notificationQueue } from "./queue";
import { getUserConfig } from "./redis";

export async function scheduleUserNotifications(userId: number) {
    const config = await getUserConfig(userId);

    // Remove existing repeatable jobs for this user
    const repeatableJobs = await notificationQueue.getRepeatableJobs();
    const userRepeatableJobs = repeatableJobs.filter((job) =>
        job.id?.startsWith(`user:${userId}:notif:`)
    );

    for (const job of userRepeatableJobs) {
        if (job.key) {
            await notificationQueue.removeRepeatableByKey(job.key);
            console.log(`🗑️ Removed repeatable job: ${job.id}`);
        }
    }

    // If user disabled or has no notifications, stop here
    if (!config || !config.enabled || config.notifications.length === 0) {
        console.log(`No active notifications for user ${userId}`);
        return;
    }

    // Add recurring job for each notification
    for (const notif of config.notifications) {
        const [hours, minutes] = notif.time.split(":").map(Number);

        // Cron pattern: "minutes hours * * *" for daily
        const cronPattern = `${minutes} ${hours} * * *`;

        await notificationQueue.add(
            "sendNotification",
            {
                userId,
                chatId: config.chatId,
                notification: notif,
            },
            {
                repeat: {
                    pattern: cronPattern,
                },
                jobId: `user:${userId}:notif:${notif.id}`,
                removeOnComplete: 10,
                removeOnFail: 5,
            }
        );

        console.log(`📅 Scheduled ${notif.time} for user ${userId}`);
    }
}
