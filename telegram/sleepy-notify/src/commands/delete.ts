import { bot } from "../bot";
import { getUserConfig, setUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";

bot.command("delete", async (ctx) => {
    const userId = ctx.from!.id;
    const args = ctx.message?.text?.split(" ").slice(1);

    if (!args || args.length === 0) {
        await ctx.reply("Usage: /delete <number>\n\nUse /list to see your reminders.");
        return;
    }

    const index = parseInt(args[0] ?? '1') - 1;
    const config = await getUserConfig(userId);

    if (!config || !config.notifications[index]) {
        await ctx.reply("❌ Invalid reminder number. Use /list to see your reminders.");
        return;
    }

    const deleted = config.notifications.splice(index, 1)[0];
    await setUserConfig(userId, config);
    await scheduleUserNotifications(userId);

    await ctx.reply(`✅ Deleted: ${deleted?.time} - ${deleted?.message}`);
});
