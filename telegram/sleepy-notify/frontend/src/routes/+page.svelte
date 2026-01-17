<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { getReminders, deleteReminder, toggleReminderDismiss } from '$lib/api';
  import { tg } from '$lib/telegram';
  import type { Reminder } from '$lib/types';

  let reminders: Reminder[] = [];
  let enabled = true;
  let loading = true;
  let error = '';

  onMount(async () => {
    tg?.MainButton.hide();
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

    async function handleDismiss(reminder: Reminder) {
        try {
            const result = await toggleReminderDismiss(reminder.id, reminder);
            tg?.HapticFeedback.impactOccurred('light');
            
            // Update the reminder in the array properly
            reminders = reminders.map(r => 
            r.id === reminder.id 
                ? { ...r, lastSentDate: result.reminder.lastSentDate }
                : r
            );
        } catch (e) {
            tg?.showAlert(e instanceof Error ? e.message : 'Failed to update');
        }
    }

  function isDismissed(reminder: Reminder): boolean {
    if (!reminder.lastSentDate) return false;
    const today = new Date().toISOString().split('T')[0];
    return reminder.lastSentDate >= today;
  }

    function getNextOccurrence(reminder: Reminder): Date {
    const [hours, minutes] = reminder.time.split(':').map(Number);
    const now = new Date();
    const today = new Date().toISOString().split('T')[0];
    
    let next = new Date();
    next.setHours(hours, minutes, 0, 0);
    
    // If lastSentDate exists and is today or in the future, next occurrence is day after lastSentDate
    if (reminder.lastSentDate && reminder.lastSentDate >= today) {
        const dismissedUntil = new Date(reminder.lastSentDate);
        dismissedUntil.setHours(hours, minutes, 0, 0);
        
        // Next occurrence is the day after lastSentDate
        next = new Date(dismissedUntil);
        next.setDate(next.getDate() + 1);
    } else {
        // Not dismissed - calculate based on current time
        if (next <= now) {
        next.setDate(next.getDate() + 1);
        }
    }
    
    return next;
    }

  function getStatusText(reminder: Reminder): string {
    const today = new Date().toISOString().split('T')[0];
    const todayDate = new Date(today);
    
    if (!reminder.lastSentDate) {
      // Not dismissed - show time until
      return getTimeUntilText(reminder);
    }
    
    const lastSentDate = new Date(reminder.lastSentDate);
    
    if (reminder.lastSentDate === today) {
      // Dismissed for today
      const [hours, minutes] = reminder.time.split(':').map(Number);
      const now = new Date();
      const todayAtReminderTime = new Date();
      todayAtReminderTime.setHours(hours, minutes, 0, 0);
      
      if (todayAtReminderTime > now) {
        // Time hasn't passed yet
        return '✓ Dismissed for today · Next: tomorrow';
      } else {
        // Time already passed (shouldn't normally happen)
        return getTimeUntilText(reminder);
      }
    } else if (lastSentDate > todayDate) {
      // Dismissed for future days
      const diffDays = Math.ceil((lastSentDate.getTime() - todayDate.getTime()) / (1000 * 60 * 60 * 24));
      const nextDay = diffDays + 1;
      return `✓ Stopped for ${diffDays} day${diffDays > 1 ? 's' : ''} · Next in ${nextDay} day${nextDay > 1 ? 's' : ''}`;
    } else {
      // lastSentDate is in the past - show time until next
      return getTimeUntilText(reminder);
    }
  }

  function getTimeUntilText(reminder: Reminder): string {
    const nextOccurrence = getNextOccurrence(reminder);
    const now = new Date();
    const diffMs = nextOccurrence.getTime() - now.getTime();
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

    if (diffHours > 24) {
      const days = Math.floor(diffHours / 24);
      return `⏳ Next in ${days} day${days > 1 ? 's' : ''}`;
    } else if (diffHours > 0) {
      return `⏳ Next in ${diffHours}h ${diffMinutes}m`;
    } else {
      return `⏳ Next in ${diffMinutes}m`;
    }
  }
</script>

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
      <div class="reminder-card" class:dismissed={isDismissed(reminder)}>
        <div class="action-buttons">
          <button 
            class="dismiss-btn" 
            class:active={isDismissed(reminder)}
            on:click={() => handleDismiss(reminder)}
            title={isDismissed(reminder) ? 'Reset' : 'Dismiss'}
          >
            {isDismissed(reminder) ? '✓' : '○'}
          </button>
          <button class="delete-btn" on:click={() => handleDelete(reminder)}>
            🗑️
          </button>
        </div>
        <div class="reminder-content">
          <div class="reminder-time">⏰ {reminder.time}</div>
          <div class="reminder-message">{reminder.message}</div>
          <div class="reminder-status">
            {getStatusText(reminder)}
          </div>
        </div>
      </div>
    {/each}
  </div>
{/if}

<button class="fab" on:click={() => goto('/create')}>+</button>

<style>
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
    transition: opacity 0.2s;
  }

  .reminder-card.dismissed {
    opacity: 0.6;
  }

  .reminder-content {
    padding-right: 80px;
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

  .reminder-status {
    font-size: 12px;
    color: var(--tg-theme-link-color);
  }

  .action-buttons {
    position: absolute;
    top: 12px;
    right: 12px;
    display: flex;
    gap: 8px;
  }

  .dismiss-btn {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: rgba(52, 199, 89, 0.15);
    color: #34c759;
    border: none;
    font-size: 16px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    transition: all 0.2s;
  }

  .dismiss-btn.active {
    background: rgba(52, 199, 89, 0.3);
  }

  .dismiss-btn:active {
    transform: scale(0.95);
  }

  .delete-btn {
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
    transition: all 0.2s;
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
    transition: transform 0.2s;
  }

  .fab:active {
    transform: scale(0.95);
  }
</style>
