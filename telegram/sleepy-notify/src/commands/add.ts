import { InlineKeyboard } from "grammy";
import { bot } from "../bot";
import { config } from "../config";

bot.command("add", async (ctx) => {
    const miniAppUrl = `${config.API_URL}/add-reminder.html`;

    console.log(`Mini App URL: ${miniAppUrl}`);

    const keyboard = new InlineKeyboard().webApp(
        "📝 Create Reminder",
        miniAppUrl
    );

    await ctx.reply("⏰ Click the button below to create a reminder:", {
        reply_markup: keyboard,
    });
});
