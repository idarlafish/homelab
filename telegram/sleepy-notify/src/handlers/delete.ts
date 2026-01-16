// src/handlers/delete-handler.ts
import { bot } from "../bot";
import { getUserConfig, setUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";

bot.hears("🗑️ Delete Reminder", async (ctx) => {
    const userId = ctx.from!.id;
    const userConfig = await getUserConfig(userId);

    if (!userConfig || userConfig.notifications.length === 0) {
        await ctx.reply("You have no reminders to delete.");
        return;
    }

    const list = userConfig.notifications
        .map((n, i) => `${i + 1}. ${n.time} - ${n.message}`)
        .join("\n");

    await ctx.reply(
        `Select a reminder to delete:\n\n${list}\n\n` +
        `Reply with the number and "delete" (e.g., "1 delete")`
    );
});

// Handle delete confirmation
bot.hears(/^(\d+)\s+delete$/i, async (ctx) => {
    const match = ctx.message!.text!.match(/^(\d+)\s+delete$/i);
    if (!match) return;

    const index = parseInt(match[1] ?? '0') - 1;
    const userId = ctx.from!.id;
    const userConfig = await getUserConfig(userId);

    if (!userConfig || !userConfig.notifications[index]) {
        await ctx.reply("❌ Invalid reminder number.");
        return;
    }

    const deleted = userConfig.notifications.splice(index, 1)[0];
    await setUserConfig(userId, userConfig);
    await scheduleUserNotifications(userId);

    await ctx.reply(`✅ Deleted: ${deleted?.time} - ${deleted?.message}`);
});
