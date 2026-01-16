// src/commands/list.ts
import { bot } from "../bot";
import { getUserConfig } from "../redis";

async function handleList(ctx: any) {
    const userId = ctx.from!.id;
    const config = await getUserConfig(userId);

    if (!config || config.notifications.length === 0) {
        await ctx.reply("You have no reminders yet. Use 📝 Add Reminder!");
        return;
    }

    const list = config.notifications
        .map((n, i) => `${i + 1}. ${n.time} - ${n.message}`)
        .join("\n");

    await ctx.reply(
        `📋 Your reminders:\n\n${list}\n\n` +
        `Status: ${config.enabled ? "✅ Enabled" : "❌ Disabled"}\n\n` +
        `Use /toggle to enable/disable\n` +
        `Use /delete <number> to remove a reminder`
    );
}

// Handle both /list command and button click
bot.command("list", handleList);
bot.hears("📋 List Reminders", handleList);
