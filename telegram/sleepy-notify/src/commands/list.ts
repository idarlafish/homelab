// src/commands/list.ts
import { bot } from "../bot";
import { getUserConfig } from "../redis";
import { InlineKeyboard } from "grammy";
import { config } from "../config";

async function handleList(ctx: any) {
    const userId = ctx.from!.id;
    const userConfig = await getUserConfig(userId);

    if (!userConfig || userConfig.notifications.length === 0) {
        await ctx.reply("You have no reminders yet. Use 📝 Add Reminder!");
        return;
    }

    // Header message
    await ctx.reply(
        `📋 Your reminders (${userConfig.notifications.length}):\n` +
        `Status: ${userConfig.enabled ? "✅ Enabled" : "❌ Disabled"}\n\n` +
        `Use /toggle to enable/disable`
    );

    // Send each reminder as a separate message with buttons immediately below
    for (const notif of userConfig.notifications) {
        // Create Mini App URL with pre-filled data
        const params = new URLSearchParams({
            id: notif.id,
            time: notif.time,
            message: notif.message,
            date: notif.lastSentDate || "",
            mode: "edit"
        });

        const editUrl = `${config.API_URL}/add-reminder.html?${params.toString()}`;

        const keyboard = new InlineKeyboard()
            .webApp("✏️ Edit", editUrl)  // ← Opens Mini App directly
            .text("🗑️ Delete", `delete_${notif.id}`);

        await ctx.reply(
            `⏰ ${notif.time} - ${notif.message}${notif.lastSentDate ? `\n📅 ${notif.lastSentDate}` : ""}`,
            { reply_markup: keyboard }
        );
    }
}

bot.command("list", handleList);
bot.hears("📋 List Reminders", handleList);
