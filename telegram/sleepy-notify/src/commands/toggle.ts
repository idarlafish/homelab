import type { BotType } from "../bot";
import { getUserConfig, setUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";

export default (bot: BotType) =>
    bot.command("toggle", async (context) => {
        const userId = context.from!.id;
        const config = await getUserConfig(userId);

        if (!config) {
            return context.send("No config found. Use `/add` first.");
        }

        config.enabled = !config.enabled;
        await setUserConfig(userId, config);
        await scheduleUserNotifications(userId); // Update schedule

        const status = config.enabled ? "✅ enabled" : "❌ disabled";
        await context.send(`Notifications are now ${status}`);
    });
