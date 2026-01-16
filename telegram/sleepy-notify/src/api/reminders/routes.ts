// src/routes/reminders.ts
import { Elysia, t } from "elysia";
import { RemindersController } from "./controller";
import { telegramAuth } from "../plugins/auth";

const controller = new RemindersController();

export const routes = new Elysia({ prefix: "/api/reminders" })
    .use(telegramAuth)

    // GET /api/reminders
    .get("/", async ({ getTelegramUser }) => {
        const user = getTelegramUser();
        return controller.getReminders(user.id);
    })

    // POST /api/reminders
    .post(
        "/",
        async ({ body, getTelegramUser }) => {
            const user = getTelegramUser();

            return controller.createReminder({
                userId: user.id,
                chatId: user.id,
                time: body.time,
                message: body.message,
                timezone: body.timezone,
            });
        },
        {
            body: t.Object({
                time: t.String({ pattern: "^([01]?[0-9]|2[0-3]):[0-5][0-9]$" }),
                message: t.String({ minLength: 1, maxLength: 500 }),
                timezone: t.String(),
            }),
        }
    )

    // DELETE /api/reminders/:id
    .delete(
        "/:id",
        async ({ params, getTelegramUser }) => {
            const user = getTelegramUser();

            return controller.deleteReminder(user.id, params.id);
        },
        {
            params: t.Object({
                id: t.String(),
            }),
        }
    );
