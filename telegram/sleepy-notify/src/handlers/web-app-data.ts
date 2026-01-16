console.log("🔧 [web-app-data.ts] Loading handler...");

import { bot } from "../bot";
import { addNotification } from "../services/notifications";

console.log("🔧 [web-app-data.ts] Registering handler...");

bot.on("message:web_app_data", async (ctx) => {
    console.log("=== WEB APP DATA RECEIVED ===");
    console.log("Full message:", ctx.msg);
    console.log("web_app_data:", ctx.msg.web_app_data);

    const webAppData = ctx.msg.web_app_data; // ← Change from ctx.message to ctx.msg

    if (!webAppData) {
        console.error("webAppData is undefined!");
        return;
    }

    console.log("Raw data string:", webAppData.data);

    try {
        const parsed = JSON.parse(webAppData.data); // ← It's just .data, not .data.json()
        console.log("Parsed data:", parsed);

        const { time, message, date } = parsed;

        const userId = ctx.from.id;
        const chatId = ctx.chat.id;

        console.log(`Adding notification for user ${userId}`);

        const notification = await addNotification(
            userId,
            chatId,
            time,
            message,
            date
        );

        console.log("Notification added:", notification);

        await ctx.reply(
            `✅ Reminder created!\n\n⏰ ${time}\n💬 ${message}${date ? `\n📅 ${date}` : ""
            }`
        );

        console.log("=== SUCCESS ===");

    } catch (error) {
        console.error("=== ERROR ===");
        console.error("Error:", error);
        await ctx.reply("❌ Failed to create reminder. Please try again.");
    }
});

console.log("🔧 [web-app-data.ts] Handler registered!");
