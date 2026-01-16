import { randomUUID } from "crypto";
import type { BotType } from "../bot";
import { getUserConfig, setUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";

const parseTime = (timeStr: string): string | null => {
    const match = timeStr.match(/^(\d{1,2}):(\d{2})$/);
    if (!match) return null;
    const [, hh, mm] = match;
    const hour = Number.parseInt(hh ?? '');
    const minute = Number.parseInt(mm ?? '');
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return `${hour.toString().padStart(2, "0")}:${minute.toString().padStart(2, "0")}`;
    }
    return null;
};

export default (bot: BotType) =>
    bot.command("add", async (context) => {
        const userId = context.from!.id;
        const chatId = context.chat.id;

        const text = context.text?.slice(5).trim(); // drop "/add "

        if (!text || text.split(" ").length < 2) {
            return context.send("❌ Usage: `/add HH:MM Your reminder text`", {
                parse_mode: "Markdown",
            });
        }

        const parts = text.split(" ");

        if (!parts[0]) {
            return context.send("❌ Usage: `/add HH:MM Your reminder text`", {
                parse_mode: "Markdown",
            });
        }

        const time = parseTime(parts[0]);
        if (!time) {
            return context.send("❌ Invalid time format. Use HH:MM (e.g., 09:00)");
        }

        const message = parts.slice(1).join(" ");

        let config = await getUserConfig(userId);
        if (!config) {
            config = { chatId, enabled: true, notifications: [] };
        } else {
            config.chatId = chatId;
        }

        const timezone = "Europe/Nicosia";

        const notification = {
            id: randomUUID(),
            time,
            message,
            timezone,
            lastSentDate: undefined as string | undefined,
        };

        config.notifications.push(notification);
        await setUserConfig(userId, config);
        await scheduleUserNotifications(userId);

        await context.send(
            `✅ Added reminder:\n⏰ *${time}* (${timezone})\n💬 ${message}`,
            { parse_mode: "Markdown" }
        );
    });

