// src/index.ts
import { bot } from "./bot";
import { config } from "./config";
import { notificationWorker } from "./queue";

// Import all commands and handlers
import "./commands/start";
import "./commands/add";
import "./commands/list";
import "./commands/delete";
import "./commands/toggle";
import "./handlers/web-app-data";

const signals = ["SIGINT", "SIGTERM"];

for (const signal of signals) {
	process.on(signal, async () => {
		console.log(`Received ${signal}. Initiating graceful shutdown...`);
		await notificationWorker.close();
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

if (config.NODE_ENV === "production") {
	const { serve } = await import("bun");

	serve({
		port: config.PORT,
		async fetch(req) {
			const url = new URL(req.url);

			if (url.pathname === `/${config.BOT_TOKEN}`) {
				const update = await req.json() as any;
				await bot.handleUpdate(update);
				return new Response("OK");
			}

			if (url.pathname === "/add-reminder.html") {
				const file = Bun.file("public/add-reminder.html");
				return new Response(file, {
					headers: { "Content-Type": "text/html" }
				});
			}

			return new Response("Not found", { status: 404 });
		},
	});

	await bot.api.setWebhook(`${config.API_URL}/${config.BOT_TOKEN}`);
	console.log(`✨ Bot ready for webhook`);

} else {
	const { serve } = await import("bun");

	serve({
		port: config.PORT,
		async fetch(req) {
			const url = new URL(req.url);
			console.log(`📥 Request: ${url.pathname}`);

			if (url.pathname === "/add-reminder.html") {
				const file = Bun.file("public/add-reminder.html");
				const exists = await file.exists();

				if (!exists) {
					console.error("❌ File not found: public/add-reminder.html");
					return new Response("File not found", { status: 404 });
				}

				console.log("✅ Serving add-reminder.html");
				return new Response(file, {
					headers: { "Content-Type": "text/html" }
				});
			}

			return new Response("Not found", { status: 404 });
		},
	});

	bot.start();
	console.log(`✨ Bot started with long polling!`);
	console.log(`📁 File server on http://localhost:${config.PORT}`);
	console.log(`🌐 Mini App URL: ${config.API_URL}/add-reminder.html`);
}
