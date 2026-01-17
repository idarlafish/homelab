import { Queue, Worker } from "bullmq";
import { redisConnection, updateLastSentDate, isAlreadySentToday, redis } from "./redis";
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
    const { userId, chatId, notification } = job.data;
    
    // Idempotency check
    if (await isAlreadySentToday(userId, notification.id)) {
      console.log(`⏭️ Already sent notification ${notification.id} today`);
      return { skipped: true, reason: 'already_sent_today' };
    }
    
    // Send message
    await sendTelegramMessage(chatId, notification.message);
    
    // Update lastSentDate
    const today = new Date().toISOString().split("T")[0]!;
    await updateLastSentDate(userId, notification.id, today);
    
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
