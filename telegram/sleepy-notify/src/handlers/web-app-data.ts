import { bot } from "../bot";
import { addNotification } from "../services/notifications";

bot.on("message:web_app_data", async (ctx) => {
    console.log("=== WEB APP DATA RECEIVED ===");

    const webAppData = ctx.message.web_app_data;

    if (!webAppData) {
        console.error("webAppData is undefined!");
        return;
    }

    console.log("Raw data:", webAppData.data);

    try {
        const { time, message, date } = JSON.parse(webAppData.data);

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
