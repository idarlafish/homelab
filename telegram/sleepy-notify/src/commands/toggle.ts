import { bot } from "../bot";
import { getUserConfig, setUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";

bot.command("toggle", async (ctx) => {
    const userId = ctx.from!.id;
    const config = await getUserConfig(userId);

    if (!config) {
        await ctx.reply("You have no reminders yet. Use /add to create one!");
        return;
    }

    config.enabled = !config.enabled;
    await setUserConfig(userId, config);
    await scheduleUserNotifications(userId);

    await ctx.reply(
        config.enabled
            ? "✅ Reminders enabled!"
            : "❌ Reminders disabled!"
    );
});
