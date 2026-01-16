import { bot } from "./bot.ts";
import { config } from "./config.ts";
import { server } from "./server/index.ts";

const signals = ["SIGINT", "SIGTERM"];

for (const signal of signals) {
	process.on(signal, async () => {
		console.log(`Received ${signal}. Initiating graceful shutdown...`);
		server.stop();
		await bot.stop();
		process.exit(0);
	});
}

process.on("uncaughtException", (error) => {
	console.error("Uncaught exception:", error);
});

process.on("unhandledRejection", (error) => {
	console.error("Unhandled rejection:", error);
});

if (config.NODE_ENV === "production")
	await bot.start({
		webhook: {
			url: `${config.API_URL}/${config.BOT_TOKEN}`,
		},
	});
else await bot.start();
