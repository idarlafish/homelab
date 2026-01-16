import env from "env-var";

export const config = {
	NODE_ENV: env
		.get("NODE_ENV")
		.default("development")
		.asEnum(["production", "test", "development"]),
	BOT_TOKEN: env.get("BOT_TOKEN").required().asString(),
	PORT: env.get("PORT").default(3000).asPortNumber(),
	API_URL: env
		.get("API_URL")
		.default(`https://${env.get("PUBLIC_DOMAIN").asString()}`)
		.asString(),
	LOCK_STORE: env.get("LOCK_STORE").default("memory").asEnum(["memory"]),
	// Redis config
	REDIS_HOST: env.get("REDIS_HOST").default("localhost").asString(),
	REDIS_PORT: env.get("REDIS_PORT").default(6379).asPortNumber(),
	REDIS_PASSWORD: env.get("REDIS_PASSWORD").asString(),
};
