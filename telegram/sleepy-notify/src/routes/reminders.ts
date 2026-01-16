// src/routes/reminders.ts
import { Elysia, t } from "elysia";
import { RemindersController } from "../controllers/reminders";

const controller = new RemindersController();

export const remindersRoutes = new Elysia({ prefix: "/api/reminders" })
    // GET /api/reminders?userId=123
    .get(
        "/",
        async ({ query }) => {
            return controller.getReminders(query.userId);
        },
        {
            query: t.Object({
                userId: t.Numeric(),
            }),
        }
    )

    // POST /api/reminders
    .post(
        "/",
        async ({ body }) => {
            return controller.createReminder(body);
        },
        {
            body: t.Object({
                userId: t.Number(),
                chatId: t.Number(),
                time: t.String({ pattern: "^([01]?[0-9]|2[0-3]):[0-5][0-9]$" }),
                message: t.String({ minLength: 1, maxLength: 500 }),
                timezone: t.String(),
            }),
        }
    )

    // DELETE /api/reminders/:id?userId=123
    .delete(
        "/:id",
        async ({ params, query }) => {
            return controller.deleteReminder(query.userId, params.id);
        },
        {
            params: t.Object({
                id: t.String(),
            }),
            query: t.Object({
                userId: t.Numeric(),
            }),
        }
    );
