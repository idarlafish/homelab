// src/commands/start.ts
import { bot } from "../bot";
import { config } from "../config";

bot.command("start", async (ctx) => {
	// Set the menu button to open Mini App
	await bot.api.setChatMenuButton({
		chat_id: ctx.chat.id,
		menu_button: {
			type: "web_app",
			text: "📝 Reminders",
			web_app: { url: `${config.API_URL}/index.html` }
		}
	});

	// Remove the reply keyboard
	await ctx.reply(
		"👋 Welcome to Sleepy Notify Bot!\n\n" +
		"Click the menu button (☰) at the bottom to manage your reminders.\n\n" +
		"Commands:\n" +
		"/list - View reminders as text\n" +
		{
			reply_markup: { remove_keyboard: true }
		}
	);
});
