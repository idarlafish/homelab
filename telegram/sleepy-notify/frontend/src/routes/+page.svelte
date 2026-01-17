<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { getReminders, deleteReminder } from '$lib/api';
  import { tg } from '$lib/telegram';
  import type { Reminder } from '$lib/types';

  let reminders: Reminder[] = [];
  let enabled = true;
  let loading = true;
  let error = '';

  onMount(async () => {
    await loadReminders();
  });

  async function loadReminders() {
    try {
      loading = true;
      error = '';
      const data = await getReminders();
      reminders = data.reminders;
      enabled = data.enabled;
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to load reminders';
      console.error('Load error:', e);
    } finally {
      loading = false;
    }
  }

  async function handleDelete(reminder: Reminder) {
    tg?.showConfirm(
      `Delete reminder?\n\n⏰ ${reminder.time}\n💬 ${reminder.message}`,
      async (confirmed) => {
        if (!confirmed) return;

        try {
          await deleteReminder(reminder.id);
          tg?.HapticFeedback.notificationOccurred('success');
          await loadReminders();
        } catch (e) {
          tg?.showAlert(e instanceof Error ? e.message : 'Failed to delete');
        }
      }
    );
  }

  function getTimeUntil(time: string): string {
    const [hours, minutes] = time.split(':').map(Number);
    const now = new Date();
    const nextNotif = new Date();
    nextNotif.setHours(hours, minutes, 0, 0);

    if (nextNotif <= now) {
      nextNotif.setDate(nextNotif.getDate() + 1);
    }

    const diffMs = nextNotif.getTime() - now.getTime();
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

    return diffHours > 0 ? `in ${diffHours}h ${diffMinutes}m` : `in ${diffMinutes}m`;
  }
</script>

<div class="header">
  <h1>📋 My Reminders</h1>
  <div class="status">
    {enabled ? '✅ Enabled' : '❌ Disabled'}
  </div>
</div>

{#if loading}
  <div class="empty-state">
    <div class="empty-state-text">Loading...</div>
  </div>
{:else if error}
  <div class="empty-state">
    <div class="empty-state-text">{error}</div>
  </div>
{:else if reminders.length === 0}
  <div class="empty-state">
    <div class="empty-state-icon">⏰</div>
    <div class="empty-state-text">
      No reminders yet.<br />
      Tap the + button to create one!
    </div>
  </div>
{:else}
  <div class="reminder-list">
    {#each reminders as reminder (reminder.id)}
      <div class="reminder-card">
        <button class="delete-btn" on:click={() => handleDelete(reminder)}>
          🗑️
        </button>
        <div class="reminder-content">
          <div class="reminder-time">⏰ {reminder.time}</div>
          <div class="reminder-message">{reminder.message}</div>
          <div class="reminder-next">⏳ Next: {getTimeUntil(reminder.time)}</div>
        </div>
      </div>
    {/each}
  </div>
{/if}

<button class="fab" on:click={() => goto('/create')}>+</button>

<style>
  .header {
    margin-bottom: 20px;
  }

  h1 {
    font-size: 24px;
    font-weight: 600;
    margin-bottom: 8px;
  }

  .status {
    font-size: 14px;
    color: var(--tg-theme-hint-color);
  }

  .empty-state {
    text-align: center;
    padding: 60px 20px;
  }

  .empty-state-icon {
    font-size: 64px;
    margin-bottom: 16px;
  }

  .empty-state-text {
    font-size: 16px;
    color: var(--tg-theme-hint-color);
  }

  .reminder-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .reminder-card {
    background: var(--tg-theme-secondary-bg-color, rgba(255, 255, 255, 0.05));
    border-radius: 12px;
    padding: 16px;
    position: relative;
  }

  .reminder-content {
    padding-right: 40px;
  }

  .reminder-time {
    font-size: 18px;
    font-weight: 600;
    margin-bottom: 4px;
  }

  .reminder-message {
    font-size: 14px;
    color: var(--tg-theme-hint-color);
    margin-bottom: 8px;
  }

  .reminder-next {
    font-size: 12px;
    color: var(--tg-theme-link-color);
  }

  .delete-btn {
    position: absolute;
    top: 12px;
    right: 12px;
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: rgba(255, 59, 48, 0.15);
    color: #ff3b30;
    border: none;
    font-size: 16px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .delete-btn:active {
    background: rgba(255, 59, 48, 0.25);
  }

  .fab {
    position: fixed;
    bottom: 80px;
    right: 20px;
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: var(--tg-theme-button-color);
    color: var(--tg-theme-button-text-color);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    cursor: pointer;
    border: none;
    z-index: 1000;
  }

  .fab:active {
    transform: scale(0.95);
  }
</style>
