import type { BotType } from "../bot";
import { getUserConfig } from "../redis";

export default (bot: BotType) =>
    bot.command("list", async (context) => {
        const userId = context.from!.id;
        const config = await getUserConfig(userId);

        if (!config || config.notifications.length === 0) {
            return context.send("📝 No notifications configured.\nUse `/add 09:00 Your reminder`");
        }

        const status = config.enabled ? "✅ enabled" : "❌ disabled";
        const lines = config.notifications.map(
            (n, i) => `${i + 1}. ⏰ *${n.time}* (${n.timezone})\n   💬 ${n.message}`
        );

        await context.send(`📋 Your notifications (${status}):\n\n${lines.join("\n\n")}`, {
            parse_mode: "Markdown",
        });
    });
