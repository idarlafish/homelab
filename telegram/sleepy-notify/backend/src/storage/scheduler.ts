import { notificationQueue } from "./queue";
import { getUserConfig } from "./redis";

export async function scheduleUserNotifications(userId: number) {
  const config = await getUserConfig(userId);
  
  // Remove all existing job schedulers for this user
  const schedulers = await notificationQueue.getJobSchedulers();
  for (const scheduler of schedulers) {
    if (scheduler.key.includes(`user:${userId}:`)) {
      await notificationQueue.removeJobScheduler(scheduler.key);
      console.log(`🗑️ Removed old scheduler: ${scheduler.key}`);
    }
  }
  
  if (!config || !config.enabled || config.notifications.length === 0) {
    console.log(`⏸️ No notifications to schedule for user ${userId}`);
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
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 5000,
        },
        removeOnComplete: 10,
        removeOnFail: 5,
      }
    );
    
    console.log(`📅 Scheduled ${notif.time} ${notif.timezone} for user ${userId}`);
  }
}
