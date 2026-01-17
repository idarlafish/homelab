import { Elysia, t } from "elysia";
import { telegramAuth } from "../plugins/auth";
import { getUserConfig, setUserConfig } from "../../storage/redis";
import { addNotification } from "../../storage/notifications";
import { scheduleUserNotifications } from "../../storage/scheduler";

export const routes = new Elysia({ prefix: "/api/reminders" })
    .use(telegramAuth)

    // GET /api/reminders
    .get("/", async ({ getTelegramUser }) => {
        const user = getTelegramUser();
        
        const userConfig = await getUserConfig(user.id);
        
        return {
            enabled: userConfig?.enabled ?? true,
            reminders: userConfig?.notifications ?? []
        };
    })

    // POST /api/reminders
    .post(
        "/",
        async ({ body, getTelegramUser }) => {
            const user = getTelegramUser();

            const { time, message, timezone } = body;
            
            if (!user.id) {
                throw new Error("Missing required fields");
            }
    
            const notification = await addNotification(user.id, user.id, time, message, timezone);
            return { success: true, notification };
        },
        {
            body: t.Object({
                time: t.String({ pattern: "^([01]?[0-9]|2[0-3]):[0-5][0-9]$" }),
                message: t.String({ minLength: 1, maxLength: 500 }),
                timezone: t.String(),
            }),
        }
    )
    
    // POST /api/reminders/:id
    .patch(
        "/:id",
        async ({ params, body, getTelegramUser }) => {
            const user = getTelegramUser();
            const reminderId = params.id;

            if (!user.id) {
                throw new Error("Missing userId");
            }

            const userConfig = await getUserConfig(user.id);

            if (!userConfig) {
                throw new Error("User config not found");
            }

            const reminder = userConfig.notifications.find(
                (n) => n.id === reminderId
            );

            if (!reminder) {
                throw new Error("Reminder not found");
            }

            // Apply partial updates
            Object.assign(reminder, body);
            
            await setUserConfig(user.id, userConfig);
            
            // Reschedule if time or timezone changed
            if (body.time || body.timezone || body.lastSentDate) {
                await scheduleUserNotifications(user.id);
            }

            console.log(`✅ Updated reminder ${reminderId} for user ${user.id}`);

            return { success: true, reminder };
        },
        {
            params: t.Object({
                id: t.String(),
            }),
            body: t.Partial(t.Object({
                time: t.String({ pattern: "^([01]?[0-9]|2[0-3]):[0-5][0-9]$" }),
                message: t.String(),
                timezone: t.String(),
                lastSentDate: t.Nullable(t.String()),
            }))
        }
    )

    // DELETE /api/reminders/:id
    .delete(
        "/:id",
        async ({ params, getTelegramUser }) => {
            const user = getTelegramUser();
            const reminderId = params.id;

            if (!user.id) {
                throw new Error("Missing userId");
            }
    
            const userConfig = await getUserConfig(user.id);
    
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
            await setUserConfig(user.id, userConfig);
            await scheduleUserNotifications(user.id);
    
            console.log(`✅ Deleted reminder ${reminderId} for user ${user.id}`);
    
            return { success: true, deleted };
        },
        {
            params: t.Object({
                id: t.String(),
            }),
        }
    );
