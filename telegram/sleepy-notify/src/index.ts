// src/index.ts
import { Elysia } from "elysia";
import { staticPlugin } from "@elysiajs/static";
import { bot } from "./bot";
import { config } from "./config";
import { notificationWorker } from "./storage/queue";
import { routes } from "./api/reminders/routes";

// Import commands
import "./commands/start";
import "./commands/list";
import { logger } from "elysia-logger";

// Graceful shutdown
const signals = ["SIGINT", "SIGTERM"];
for (const signal of signals) {
	process.on(signal, async () => {
		console.log(`Received ${signal}. Shutting down...`);
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

// Create Elysia app
const app = new Elysia()
	// Global error handler
	.onError(({ code, error, set }) => {
		console.error(`[${code}]`, error);

		if (code === "VALIDATION") {
			set.status = 400;
			return {
				error: "Validation failed",
				details: error instanceof Error ? error.message : String(error)
			};
		}

		if (code === "NOT_FOUND") {
			set.status = 404;
			return { error: "Not found" };
		}

		set.status = 500;
		return {
			error: error instanceof Error ? error.message : "Internal server error"
		};
	})

	// Request logging (dev only)
	.onRequest(({ request }) => {
		if (config.NODE_ENV === "development") {
			console.log(`📥 ${request.method} ${new URL(request.url).pathname}`);
		}
	})

	// Webhook endpoint (production only)
	.post(
		`/${config.BOT_TOKEN}`,
		async ({ body }) => {
			if (config.NODE_ENV === "production") {
				await bot.handleUpdate(body as any);
				return "OK";
			}
			return { error: "Webhook only available in production" };
		}
	)

	// API routes
	.use(routes)

	// Static files (Mini App)
	.use(
		staticPlugin({
			assets: "public",
			prefix: "/",
		})
	)
	// Elysia logger
	.use(logger())

	// Start server
	.listen(config.PORT);

console.log(`🚀 Server running on http://localhost:${app.server?.port}`);

// Bot startup
if (config.NODE_ENV === "production") {
	await bot.api.setWebhook(`${config.API_URL}/${config.BOT_TOKEN}`);
	console.log(`✨ Bot ready for webhook`);
} else {
	bot.start();
	console.log(`✨ Bot started with long polling!`);
	console.log(`🌐 Mini App: ${config.API_URL}/index.html`);
}
