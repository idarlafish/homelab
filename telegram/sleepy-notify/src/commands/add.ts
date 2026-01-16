// src/commands/add.ts
import { InlineKeyboard } from "gramio";
import type { BotType } from "../bot";

export default (bot: BotType) =>
    bot.command("add", async (context) => {
        const miniAppUrl = `${process.env.API_URL}/add-reminder.html`;

        await context.send("⏰ Click the button below to create a reminder:", {
            reply_markup: new InlineKeyboard().webApp(
                "📝 Create Reminder",
                miniAppUrl
            )
        });
    });
