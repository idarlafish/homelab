import { bot } from "../bot";
import { getUserConfig } from "../redis";

bot.command("list", async (ctx) => {
    const userId = ctx.from!.id;
    const config = await getUserConfig(userId);

    if (!config || config.notifications.length === 0) {
        await ctx.reply("You have no reminders yet. Use /add to create one!");
        return;
    }

    const list = config.notifications
        .map((n, i) => `${i + 1}. ${n.time} - ${n.message}`)
        .join("\n");

    await ctx.reply(
        `📋 Your reminders:\n\n${list}\n\nStatus: ${config.enabled ? "✅ Enabled" : "❌ Disabled"}`
    );
});
