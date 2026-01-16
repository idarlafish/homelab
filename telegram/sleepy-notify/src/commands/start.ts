import type { BotType } from "../bot.ts";

export default (bot: BotType) =>
	bot.command("start", (context) => context.send("Hi!"));
