// src/keyboards.ts
import { Keyboard } from "grammy";
import { config } from "./config";

export function getMainKeyboard() {
    return new Keyboard()
        .webApp("📝 Add Reminder", `${config.API_URL}/add-reminder.html`)
        .text("📋 List Reminders")
        .resized()
        .persistent();
}
