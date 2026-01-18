import { notificationQueue } from "./queue";
import { getUserConfig } from "./redis";

export async function scheduleUserNotifications(userId: number) {
  const config = await getUserConfig(userId);
  
  if (!config || config.notifications.length === 0) {
    console.log(`⏸️ No notifications to schedule for user ${userId}`);
    return;
  }
  
  for (const notif of config.notifications) {
    const [hours, minutes] = notif.time.split(":").map(Number);
    const cronPattern = `${minutes} ${hours} * * *`;
    
    // BullMQ will deduplicate jobs with the same jobId + repeat pattern
    await notificationQueue.add(
      "sendNotification",
      { userId, chatId: config.chatId, notification: notif },
      {
        repeat: {
          pattern: cronPattern,
          tz: notif.timezone,
        },
        jobId: `user:${userId}:notif:${notif.id}`,
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 5000,
        },
        removeOnComplete: 10,
        removeOnFail: 5,
      }
    );
    
    console.log(`📅 Scheduled ${notif.time} ${notif.timezone} for user ${userId} (id: ${notif.id})`);
  }
}
