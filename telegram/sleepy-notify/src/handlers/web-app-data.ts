// src/handlers/web-app-data.ts
import { bot } from "../bot";
import { addNotification } from "../services/notifications";
import { getUserConfig, setUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";

bot.on("message:web_app_data", async (ctx) => {
    console.log("=== WEB APP DATA RECEIVED ===");

    const webAppData = ctx.msg.web_app_data;

    if (!webAppData) {
        console.error("webAppData is undefined!");
        return;
    }

    console.log("Raw data:", webAppData.data);

    try {
        const { time, message, lastSentDate, mode, id } = JSON.parse(webAppData.data);

        const userId = ctx.from.id;
        const chatId = ctx.chat.id;

        if (mode === 'edit' && id) {
            // Update existing reminder
            console.log(`Updating reminder ${id} for user ${userId}`);

            const config = await getUserConfig(userId);
            if (!config) {
                await ctx.reply("❌ Could not find your reminders.");
                return;
            }

            const reminderIndex = config.notifications.findIndex(n => n.id === id);
            if (reminderIndex === -1) {
                await ctx.reply("❌ Reminder not found.");
                return;
            }

            const existingReminder = config.notifications[reminderIndex];
            if (!existingReminder) {
                await ctx.reply("❌ Reminder not found.");
                return;
            }

            // Update the reminder
            config.notifications[reminderIndex] = {
                id: existingReminder.id,
                timezone: existingReminder.timezone,
                time,
                message,
                lastSentDate: existingReminder.lastSentDate,
            };

            await setUserConfig(userId, config);
            await scheduleUserNotifications(userId);

            console.log("Reminder updated:", id);

            await ctx.reply(
                `✅ Reminder updated!\n\n⏰ ${time}\n💬 ${message}${lastSentDate ? `\n📅 ${lastSentDate}` : ""
                }`
            );
        } else {
            // Create new reminder
            console.log(`Adding notification for user ${userId}`);

            const notification = await addNotification(
                userId,
                chatId,
                time,
                message,
                lastSentDate
            );

            console.log("Notification added:", notification);

            await ctx.reply(
                `✅ Reminder created!\n\n⏰ ${time}\n💬 ${message}${lastSentDate ? `\n📅 ${lastSentDate}` : ""
                }`
            );
        }

        console.log("=== SUCCESS ===");

    } catch (error) {
        console.error("=== ERROR ===");
        console.error("Error:", error);
        await ctx.reply("❌ Failed to save reminder. Please try again.");
    }
});
