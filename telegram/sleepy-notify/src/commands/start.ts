import type { BotType } from "../bot";
import { getUserConfig, setUserConfig } from "../redis";

export default (bot: BotType) =>
	bot.command("start", async (context) => {
		const userId = context.from!.id;
		const chatId = context.chat.id;

		let config = await getUserConfig(userId);
		if (!config) {
			config = {
				chatId,
				enabled: true,
				notifications: [],
			};
			await setUserConfig(userId, config);
		} else {
			config.chatId = chatId;
			await setUserConfig(userId, config);
		}

		await context.send(
			`🤖 *Welcome to Scheduler Bot!*\n\n` +
			`Commands:\n` +
			`• /add 09:00 Your reminder – add notification\n` +
			`• /list – show your notifications\n` +
			`• /toggle – enable/disable all\n` +
			`• /delete – delete all data (GDPR)`,
			{ parse_mode: "Markdown" }
		);
	});
