import { bot } from "../bot";

bot.command("start", async (ctx) => {
	await ctx.reply(
		"👋 Welcome to Sleepy Notify Bot!\n\n" +
		"Commands:\n" +
		"/add - Create a new reminder\n" +
		"/list - View your reminders\n" +
		"/delete <number> - Delete a reminder\n" +
		"/toggle - Enable/disable reminders"
	);
});
