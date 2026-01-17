import { bot } from "../bot";

bot.callbackQuery('done', async (ctx) => {
  await ctx.deleteMessage();
  await ctx.answerCallbackQuery({ text: '✓ Done!' });
  console.log(`🗑️ User completed notification`);
});
