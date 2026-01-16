import { bot } from "../bot";
import { getUserConfig } from "../storage/redis";

async function handleList(ctx: any) {
    const userId = ctx.from!.id;
    const userConfig = await getUserConfig(userId);

    if (!userConfig || userConfig.notifications.length === 0) {
        await ctx.reply("You have no reminders yet. Open the menu (☰) to create one!");
        return;
    }

    let message = `📋 Your reminders (${userConfig.notifications.length}):\n`;
    message += `Status: ${userConfig.enabled ? "✅ Enabled" : "❌ Disabled"}\n\n`;

    const now = new Date();

    for (const notif of userConfig.notifications) {
        const [hours, minutes] = notif.time.split(':').map(Number);
        const nextNotif = new Date();
        nextNotif.setHours(hours ?? 0, minutes, 0, 0);

        if (nextNotif <= now) {
            nextNotif.setDate(nextNotif.getDate() + 1);
        }

        const diffMs = nextNotif.getTime() - now.getTime();
        const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
        const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

        const timeUntil = diffHours > 0
            ? `in ${diffHours}h ${diffMinutes}m`
            : `in ${diffMinutes}m`;

        message += `⏰ ${notif.time} - ${notif.message}\n`;
        message += `   ⏳ Next: ${timeUntil}\n\n`;
    }

    await ctx.reply(message);
}

bot.command("list", handleList);
