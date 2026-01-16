// src/commands/start.ts
import { bot } from "../bot";
import { getMainKeyboard } from "../keyboards";

bot.command("start", async (ctx) => {
	await ctx.reply(
		"👋 Welcome to Sleepy Notify Bot!\n\n" +
		"Use the buttons below to manage your reminders:",
		{ reply_markup: getMainKeyboard() }
	);
});
