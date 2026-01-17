import { Queue, Worker } from "bullmq";
import { redisConnection, updateLastSentDate, isAlreadySentToday, redis, getUserConfig, setUserConfig } from "./redis";
import { bot } from "../bot";
import type { NotificationJob } from "./types";

export const notificationQueue = new Queue<NotificationJob>("notifications", {
  connection: redisConnection,
});

async function sendTelegramMessage(chatId: number, message: string): Promise<void> {
  try {
    await bot.api.sendMessage(chatId, message, { disable_notification: false });
    console.log(`✅ Sent notification to ${chatId}: ${message}`);
  } catch (error: any) {
    if (error?.description?.includes("blocked")) {
      console.log(`🚫 User ${chatId} blocked the bot`);
      throw new Error("USER_BLOCKED");
    }
    throw error;
  }
}

export const notificationWorker = new Worker<NotificationJob>(
  "notifications",
  async (job) => {
    const { userId, notification } = job.data;
    
    // CRITICAL: Fetch fresh config from Redis, don't trust job data
    const config = await getUserConfig(userId);
    
    if (!config) {
      console.log(`⏭️ User config not found for ${userId}`);
      return { skipped: true, reason: 'config_not_found' };
    }
    
    // Find the current version of this notification
    const currentNotif = config.notifications.find(n => n.id === notification.id);
    
    if (!currentNotif) {
      console.log(`⏭️ Notification ${notification.id} no longer exists`);
      return { skipped: true, reason: 'notification_deleted' };
    }
    
    const today = new Date().toISOString().split("T")[0]!;
    
    // Check if already sent or dismissed
    if (currentNotif.lastSentDate === today || 
        (currentNotif.lastSentDate && currentNotif.lastSentDate > today)) {
      console.log(`⏭️ Already sent notification ${currentNotif.id} today (lastSentDate: ${currentNotif.lastSentDate})`);
      return { skipped: true, reason: 'already_sent_or_dismissed' };
    }
    
    // Send with current message (in case it was edited)
    await sendTelegramMessage(config.chatId, currentNotif.message);
    
    // Update lastSentDate in Redis
    currentNotif.lastSentDate = today;
    await setUserConfig(userId, config);
    console.log(`📝 Updated lastSentDate for ${currentNotif.id} to ${today}`);
    
    return { sent: true, timestamp: new Date().toISOString() };
  },
  {
    connection: redisConnection,
    limiter: { max: 20, duration: 1000 },
    removeOnComplete: { count: 10 },
    removeOnFail: { count: 5 },
  }
);


notificationWorker.on("completed", (job) => {
  console.log(`✓ Job ${job.id} completed`);
});

notificationWorker.on("failed", (job, err) => {
  console.error(`✗ Job ${job?.id} failed:`, err.message);
});
