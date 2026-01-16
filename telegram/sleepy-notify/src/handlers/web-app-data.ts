console.log("🔧 [web-app-data.ts] FILE IS LOADING");

import type { BotType } from "../bot";
import { addNotification } from "../services/notifications";

export default (bot: BotType) =>
    bot.on("web_app_data", async (context) => {
        console.log("=== WEB APP DATA RECEIVED ===");
        console.log("Context:", context);

        // Type guard
        if (!context.webAppData) {
            console.error("webAppData is undefined!");
            return;
        }

        console.log("Raw data:", context.webAppData.data);

        try {
            const parsed = JSON.parse(context.webAppData.data);
            console.log("Parsed data:", parsed);

            const { time, message, date } = parsed;

            if (!context.from) {
                console.error("context.from is undefined!");
                return;
            }

            const userId = context.from.id;
            const chatId = context.chat.id;

            console.log(`Adding notification for user ${userId}`);

            // Call centralized logic
            const notification = await addNotification(
                userId,
                chatId,
                time,
                message,
                date
            );

            console.log("Notification added:", notification);

            await context.send(
                `✅ Reminder created!\n\n⏰ ${time}\n💬 ${message}${date ? `\n📅 ${date}` : ""
                }`
            );

            console.log("=== SUCCESS ===");

        } catch (error) {
            console.error("=== ERROR ===");
            console.error("Error:", error);
            await context.send("❌ Failed to create reminder. Please try again.");
        }
    });
