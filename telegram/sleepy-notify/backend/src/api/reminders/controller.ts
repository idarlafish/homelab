import { getUserConfig, setUserConfig } from "../../storage/redis";
import { addNotification } from "../../storage/notifications";
import { scheduleUserNotifications } from "../../storage/scheduler";

export class RemindersController {
    async getReminders(userId: number) {
        if (!userId) {
            throw new Error("Missing userId");
        }

        const userConfig = await getUserConfig(userId);

        return {
            enabled: userConfig?.enabled ?? true,
            reminders: userConfig?.notifications ?? []
        };
    }

    async createReminder(data: {
        userId: number;
        chatId: number;
        time: string;
        message: string;
        timezone: string;
    }) {
        const { userId, chatId, time, message, timezone } = data;

        if (!userId || !chatId || !time || !message || !timezone) {
            throw new Error("Missing required fields");
        }

        const notification = await addNotification(userId, chatId, time, message, timezone);
        return { success: true, notification };
    }

    async deleteReminder(userId: number, reminderId: string) {
        if (!userId || !reminderId) {
            throw new Error("Missing userId or reminderId");
        }

        const userConfig = await getUserConfig(userId);

        if (!userConfig) {
            throw new Error("User config not found");
        }

        const reminderIndex = userConfig.notifications.findIndex(
            (n) => n.id === reminderId
        );

        if (reminderIndex === -1) {
            throw new Error("Reminder not found");
        }

        const deleted = userConfig.notifications.splice(reminderIndex, 1)[0];
        await setUserConfig(userId, userConfig);
        await scheduleUserNotifications(userId);

        console.log(`✅ Deleted reminder ${reminderId} for user ${userId}`);

        return { success: true, deleted };
    }
}
