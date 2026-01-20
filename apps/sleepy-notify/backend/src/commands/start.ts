import { bot } from "../bot";
import { config } from "../config";

bot.command("start", async (ctx) => {
	await bot.api.setChatMenuButton({
		chat_id: ctx.chat.id,
		menu_button: {
			type: "web_app",
			text: "Start",
			web_app: { url: config.API_URL },
		},
	});

	await ctx.reply("👋 Welcome to Sleepy Notify Bot!");
});
