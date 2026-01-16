// src/handlers/callback-handlers.ts
import { bot } from "../bot";
import { getUserConfig, setUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";
import { InlineKeyboard, Keyboard } from "grammy";

// Handle delete button - show confirmation
bot.callbackQuery(/^delete_(.+)$/, async (ctx) => {
    const reminderId = ctx.match[1];
    const userId = ctx.from.id;
    const userConfig = await getUserConfig(userId);

    if (!userConfig) {
        await ctx.answerCallbackQuery("Reminders not found.");
        return;
    }

    const reminder = userConfig.notifications.find(n => n.id === reminderId);

    if (!reminder) {
        await ctx.answerCallbackQuery("Reminder not found.");
        return;
    }

    const keyboard = new InlineKeyboard()
        .text("❌ Yes, delete it", `confirm_delete_${reminderId}`)
        .text("Cancel", `cancel_delete`);

    await ctx.answerCallbackQuery();
    await ctx.editMessageText(
        `⚠️ Are you sure you want to delete this reminder?\n\n` +
        `⏰ ${reminder.time}\n💬 ${reminder.message}`,
        { reply_markup: keyboard }
    );
});

// Handle delete confirmation
bot.callbackQuery(/^confirm_delete_(.+)$/, async (ctx) => {
    const reminderId = ctx.match[1];
    const userId = ctx.from.id;
    const userConfig = await getUserConfig(userId);

    if (!userConfig) {
        await ctx.answerCallbackQuery("Reminders not found.");
        return;
    }

    const reminderIndex = userConfig.notifications.findIndex(n => n.id === reminderId);

    if (reminderIndex === -1) {
        await ctx.answerCallbackQuery("Reminder not found.");
        return;
    }

    const deleted = userConfig.notifications.splice(reminderIndex, 1)[0];
    await setUserConfig(userId, userConfig);
    await scheduleUserNotifications(userId);

    await ctx.answerCallbackQuery("Reminder deleted!");
    await ctx.editMessageText(
        `✅ Deleted reminder:\n\n⏰ ${deleted?.time}\n💬 ${deleted?.message}`
    );
});

// Handle cancel
bot.callbackQuery("cancel_delete", async (ctx) => {
    await ctx.answerCallbackQuery("Cancelled");
    await ctx.editMessageText("❌ Deletion cancelled.");
});
