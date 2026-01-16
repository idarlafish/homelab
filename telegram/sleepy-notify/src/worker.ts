import { notificationWorker } from "./queue";
import { bot } from "./bot";

notificationWorker.on("completed", (job) => {
    console.log(`✅ Job ${job.id} completed`);
});

notificationWorker.on("failed", (job, err) => {
    console.error(`❌ Job ${job?.id} failed:`, err);
});

console.log("🔄 Notification worker started");
