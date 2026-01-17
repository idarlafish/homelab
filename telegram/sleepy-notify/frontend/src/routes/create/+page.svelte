<!-- frontend/src/routes/create/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { createReminder } from '$lib/api';
  import { tg, getTimezone } from '$lib/telegram';

  let time = '09:00';
  let message = '';
  let saving = false;

  onMount(() => {
    tg?.BackButton.show();
    tg?.BackButton.onClick(() => goto('/'));

    tg?.MainButton.setText('Save Reminder');
    tg?.MainButton.show();
    tg?.MainButton.onClick(handleSave);
  });

  async function handleSave() {
    if (!time || !message.trim()) {
      tg?.showAlert('Please fill all fields');
      return;
    }

    saving = true;
    tg?.MainButton.showProgress();

    try {
      await createReminder({
        time,
        message: message.trim(),
        timezone: getTimezone(),
      });

      tg?.showPopup(
        {
          message: '✅ Reminder created!',
          buttons: [{ type: 'ok' }],
        },
        () => goto('/')
      );
    } catch (e) {
      tg?.showAlert(e instanceof Error ? e.message : 'Failed to save');
      tg?.MainButton.hideProgress();
      saving = false;
    }
  }
</script>

<div class="header">
  <h1>📝 Create Reminder</h1>
</div>

<div class="form-group">
  <label for="time">⏰ Time</label>
  <input type="time" id="time" bind:value={time} required disabled={saving} />
</div>

<div class="form-group">
  <label for="message">💬 Message</label>
  <textarea
    id="message"
    bind:value={message}
    placeholder="What should I remind you about?"
    required
    disabled={saving}
  ></textarea>
</div>

<style>
  .header {
    margin-bottom: 24px;
  }

  h1 {
    font-size: 24px;
    font-weight: 600;
  }

  .form-group {
    margin-bottom: 20px;
  }

  label {
    display: block;
    margin-bottom: 8px;
    font-weight: 500;
    font-size: 14px;
  }

  input[type='time'],
  textarea {
    width: 100%;
    padding: 12px;
    border: 1px solid var(--tg-theme-hint-color);
    border-radius: 8px;
    font-size: 16px;
    background: var(--tg-theme-secondary-bg-color, rgba(255, 255, 255, 0.05));
    color: var(--tg-theme-text-color);
    font-family: inherit;
  }

  textarea {
    min-height: 100px;
    resize: vertical;
  }

  input:disabled,
  textarea:disabled {
    opacity: 0.6;
  }
</style>
