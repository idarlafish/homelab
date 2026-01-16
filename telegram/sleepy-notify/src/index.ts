import { bot } from "./bot.ts";
import { config } from "./config.ts";
import { notificationWorker } from "./queue.ts";

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
	// Production: webhook
	const { server } = await import("./server/index.ts");
	await bot.start({
		webhook: {
			url: `${config.API_URL}/${config.BOT_TOKEN}`,
		},
	});
	console.log(`✨ Bot ready for webhook`);
} else {
	// Development: long polling + file server for Mini Apps
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

	await bot.start();
	console.log(`✨ Bot started with long polling!`);
	console.log(`📁 File server on http://localhost:${config.PORT}`);
	console.log(`🌐 Mini App URL: ${config.API_URL}/add-reminder.html`);
}
