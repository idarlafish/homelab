import { randomUUID } from "node:crypto";
import { getUserConfig, setUserConfig } from "../redis";
import { scheduleUserNotifications } from "../scheduler";

export async function addNotification(
    userId: number,
    chatId: number,
    time: string,
    message: string,
    date?: string // Optional: specific date
) {
    // Validate time
    if (!/^\d{2}:\d{2}$/.test(time)) {
        throw new Error("Invalid time format");
    }

    // Get or create config
    let config = await getUserConfig(userId);
    if (!config) {
        config = { chatId, enabled: true, notifications: [] };
    } else {
        config.chatId = chatId;
    }

    // Add notification
    const notification = {
        id: randomUUID(),
        time,
        message,
        date, // Add date field if you want one-time reminders
        timezone: "Europe/Nicosia",
        lastSentDate: undefined,
    };

    config.notifications.push(notification);
    await setUserConfig(userId, config);
    await scheduleUserNotifications(userId);

    return notification;
}
