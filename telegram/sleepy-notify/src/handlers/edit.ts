// src/handlers/edit-handler.ts
import { bot } from "../bot";
import { getUserConfig } from "../redis";
import { Keyboard } from "grammy";
import { config } from "../config";

bot.hears("✏️ Edit Reminder", async (ctx) => {
    const userId = ctx.from!.id;
    const userConfig = await getUserConfig(userId);

    if (!userConfig || userConfig.notifications.length === 0) {
        await ctx.reply("You have no reminders to edit. Use 📝 Add Reminder!");
        return;
    }

    const list = userConfig.notifications
        .map((n, i) => `${i + 1}. ${n.time} - ${n.message}`)
        .join("\n");

    await ctx.reply(
        `Select a reminder to edit:\n\n${list}\n\n` +
        `Reply with the number (e.g., "1")`
    );
});

// Handle number selection for editing
bot.hears(/^\d+$/, async (ctx) => {
    const index = parseInt(ctx.message!.text!) - 1;
    const userId = ctx.from!.id;
    const userConfig = await getUserConfig(userId);

    if (!userConfig || !userConfig.notifications[index]) {
        return; // Invalid number, ignore
    }

    const reminder = userConfig.notifications[index];

    // Create Mini App URL with pre-filled data
    const params = new URLSearchParams({
        id: reminder.id,
        time: reminder.time,
        message: reminder.message,
        date: reminder.lastSentDate || "",
        mode: "edit"
    });

    const editUrl = `${config.API_URL}/add-reminder.html?${params.toString()}`;

    const keyboard = new Keyboard()
        .webApp("✏️ Edit This Reminder", editUrl)
        .resized()
        .oneTime();

    await ctx.reply(
        `Edit reminder:\n\n⏰ ${reminder.time}\n💬 ${reminder.message}\n\n` +
        `Click the button below to edit:`,
        { reply_markup: keyboard }
    );
});
