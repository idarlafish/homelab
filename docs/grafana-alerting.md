# Grafana alerting — Telegram contact point

Wire Grafana to send alerts via a Telegram bot. One-time setup, ~3 minutes.

## Prereqs

- A bot token (use the existing prod bot or create a separate alerts-only bot
  via @BotFather — a separate bot is cleaner so user-facing notifications and
  ops alerts don't share a chat).
- The chat_id you want alerts delivered to. For your own user: send `/start`
  to the alerts bot, then `curl https://api.telegram.org/bot<TOKEN>/getUpdates`
  and copy `result[0].message.chat.id`.

## Steps

1. Open `grafana.la.fish` → log in.
2. **Alerting → Contact points → Add contact point.**
   - Name: `telegram`
   - Integration: `Telegram`
   - BOT API Token: your bot token
   - Chat ID: your chat_id
   - Save.
3. **Alerting → Notification policies → Edit default policy.**
   - Default contact point: `telegram`
   - Save.
4. **Test:** click the contact point → "Test" — you should get a message in
   the chat within a few seconds.

That's it — the `TelegramNotifyCronStale` rule (in
`k8s/apps/tools/monitoring/telegram-notify-rules.yaml`) routes through this
default policy and fires when `/health/cron` is non-200 for 3+ minutes.
