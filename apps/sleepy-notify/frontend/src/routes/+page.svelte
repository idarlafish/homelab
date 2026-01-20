<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { getReminders, deleteReminder, toggleReminderDismiss } from '$lib/api';
  import { tg } from '$lib/telegram';
  import type { Reminder } from '$lib/types';

  // Import SVG files as raw strings
  import moonSvg from '$lib/assets/moon.svg?raw';
  import sunSvg from '$lib/assets/sun.svg?raw';
  import sunsetSvg from '$lib/assets/sunset.svg?raw';
  import sunriseSvg from '$lib/assets/sunrise.svg?raw';
  import ActionButton from '$lib/components/ActionButton.svelte';

  let reminders: Reminder[] = [];
  let enabled = true;
  let loading = true;
  let error = '';
  let now = Date.now();

  // Reactive: recalculates whenever 'now' or 'reminders' changes
  $: reminderStates = reminders.map(reminder => {
    const currentTime = new Date(now);
    const today = currentTime.toISOString().split('T')[0];
    
    const isDismissed = reminder.lastSentDate && reminder.lastSentDate >= today;
    const [hours, minutes] = reminder.time.split(':').map(Number);
    
    let next = new Date(currentTime);
    next.setHours(hours, minutes, 0, 0);
    
    if (reminder.lastSentDate && reminder.lastSentDate >= today) {
      const dismissedUntil = new Date(reminder.lastSentDate);
      dismissedUntil.setHours(hours, minutes, 0, 0);
      next = new Date(dismissedUntil);
      next.setDate(next.getDate() + 1);
    } else {
      if (next <= currentTime) {
        next.setDate(next.getDate() + 1);
      }
    }
    
    const diffMs = next.getTime() - currentTime.getTime();
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

    let statusText = '';
    if (diffHours > 24) {
      const days = Math.floor(diffHours / 24);
      statusText = `⏳ Next in ${days} day${days > 1 ? 's' : ''}`;
    } else if (diffHours > 0) {
      statusText = `⏳ Next in ${diffHours}h ${diffMinutes}m`;
    } else {
      statusText = `⏳ Next in ${diffMinutes}m`;
    }
    
    return {
      ...reminder,
      // isDismissed: !!isDismissed,
      isDismissed: false,
      statusText
    };
  });

  onMount(() => {
    tg?.BackButton.hide();
    tg?.MainButton.setText('Create Reminder');
    tg?.MainButton.hideProgress();
    tg?.MainButton.show();
    tg?.MainButton.onClick(handleCreate);
    
    loadReminders();

    const current = new Date();
    const msUntilNextMinute = (60 - current.getSeconds()) * 1000 - current.getMilliseconds();
    let interval: NodeJS.Timeout;
    
    const timeout = setTimeout(() => {
      now = Date.now();
      
      interval = setInterval(() => {
        now = Date.now();
      }, 60000);
    }, msUntilNextMinute);
    
    return () => {
      clearTimeout(timeout);
      clearInterval(interval);
    };
  });

  onDestroy(() => {
    tg?.MainButton.offClick(handleCreate);
  });

  function handleCreate() {
    goto('/create');
  }

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
      
      reminders = reminders.map(r => 
        r.id === reminder.id 
          ? { ...r, lastSentDate: result.reminder.lastSentDate }
          : r
      );
    } catch (e) {
      tg?.showAlert(e instanceof Error ? e.message : 'Failed to update');
    }
  }

  function getTimePeriod(time: string): string {
    const hour = parseInt(time.split(':')[0]);
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'day';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  function getIconSvg(time: string): string {
    const period = getTimePeriod(time);
    switch (period) {
      case 'morning':
        return sunriseSvg;
      case 'day':
        return sunSvg;
      case 'evening':
        return sunsetSvg;
      case 'night':
        return moonSvg;
      default:
        return moonSvg;
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
{:else if reminderStates.length === 0}
  <div class="empty-state">
    <div class="empty-state-icon">⏰</div>
    <div class="empty-state-text">
      No reminders yet.<br />
      Tap the + button to create one!
    </div>
  </div>
{:else}
<div class="reminder-list">
  {#each reminderStates as reminder (reminder.id)}
    <div class="card" class:dismissed={reminder.isDismissed} data-time-period={getTimePeriod(reminder.time)}>
      <div class="action-buttons">
        <!-- No dismiss yet -->
        <!-- <button 
          class="dismiss-btn" 
          class:active={reminder.isDismissed}
          on:click={() => handleDismiss(reminder)}
          title={reminder.isDismissed ? 'Reset' : 'Dismiss'}
        >
          {reminder.isDismissed ? '✓' : '○'}
        </button> -->

        <ActionButton 
            type="delete" 
            text="Delete"
            onClick={() => handleDelete(reminder)}
        />
      </div>
      
      <p class="time-text"><span>{reminder.time}</span></p>
      <p class="day-text">{reminder.message}</p>
      <p class="status-text">{reminder.statusText}</p>
      
      <div class="icon">
        {@html getIconSvg(reminder.time)}
      </div>
    </div>
  {/each}
</div>
{/if}

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

.card {
  width: 100%;
  height: 150px;
  border-radius: 15px;
    box-shadow:
        1px 2px 2px hsl(220deg 60% 50% / 0.333),
        2px 4px 4px hsl(220deg 60% 50% / 0.333),
        3px 6px 6px hsl(220deg 60% 50% / 0.333);
display: flex;
  color: white;
  justify-content: center;
  position: relative;
  flex-direction: column;
  cursor: pointer;
  transition: all 0.3s ease-in-out;
  overflow: hidden;
}

/* Time-based backgrounds */
.card[data-time-period="morning"] {
  background: linear-gradient(to right, #87ceeb, #fdfbd3);
}

.card[data-time-period="day"] {
  background: linear-gradient(to right, #ff8c42, #fcd14d);
}

.card[data-time-period="evening"] {
  background: linear-gradient(to right, #d66ba0, #ffb68a);
}

.card[data-time-period="night"] {
  background: linear-gradient(to right, #1a2332, #c2c5cc);
}

.card.dismissed {
  opacity: 0.9;
}

.time-text {
  font-size: 50px;
  margin-top: 0px;
  margin-left: 15px;
  margin-bottom: 5px;
  font-weight: 600;
  font-family: 'Gill Sans', 'Gill Sans MT', Calibri, 'Trebuchet MS', sans-serif;
}

.day-text {
  font-size: 18px;
  margin-top: 0px;
  margin-left: 15px;
  margin-bottom: 5px;
  font-weight: 500;
  font-family: 'Gill Sans', 'Gill Sans MT', Calibri, 'Trebuchet MS', sans-serif;
}

.status-text {
  font-size: 14px;
  margin-top: 0px;
  margin-left: 15px;
  margin-bottom: 0px;
  opacity: 0.9;
  font-family: 'Gill Sans', 'Gill Sans MT', Calibri, 'Trebuchet MS', sans-serif;
}

.icon {
  position: absolute;
  right: 12px;
  top: 12px;
  width: 20px;
  height: 20px;
  transition: transform 0.3s ease-in-out;
  will-change: transform;
}

.icon :global(svg) {
  width: 100%;
  height: 100%;
}

.card:hover .icon {
    transform: scale(1.2);
}

.action-buttons {
  position: absolute;
  bottom: 12px;
  right: 12px;
  display: flex;
  gap: 8px;
  z-index: 10;
  width: 150px;
}

/* no dismiss for now */
/* .dismiss-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border: none;
  font-size: 16px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  transition: all 0.2s;
  backdrop-filter: blur(10px);
}

.dismiss-btn.active {
  background: rgba(76, 175, 80, 0.4);
}

.dismiss-btn:active {
  transform: scale(0.95);
} */
</style>
