import type { BotType } from "../bot";
import { deleteUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";

export default (bot: BotType) =>
    bot.command("delete", async (context) => {
        const userId = context.from!.id;
        await deleteUserConfig(userId);
        await scheduleUserNotifications(userId); // Remove all jobs

        await context.send(
            "🗑️ All your data has been deleted (GDPR compliant).\n" +
            "Start over with `/start`"
        );
    });
