import { getInitData } from './telegram.ts';
import type { RemindersResponse, CreateReminderRequest, Reminder } from './types';

const API_BASE = import.meta.env.DEV ? 'http://localhost:3000' : '';
// const API_BASE = import.meta.env.DEV ? 'https://chan-intercrural-lissa.ngrok-free.dev' : '';

async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
    const initData = getInitData();
    
    const fullUrl = `${API_BASE}${endpoint}`;
    console.log('Fetching:', fullUrl);
    console.log('Init data length:', initData.length);

    try {
        const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `tma ${initData}`,
      ...options.headers,
    },
        });
        
        console.log('Response status:', response.status);

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }

  return response.json();
    } catch(e) {
        console.error(e);
        return Promise.reject(e);
    }
}

export async function getReminders(): Promise<RemindersResponse> {
  return apiRequest<RemindersResponse>('/api/reminders');
}

export async function createReminder(data: CreateReminderRequest): Promise<{ success: boolean; notification: Reminder }> {
  return apiRequest('/api/reminders', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function toggleReminderDismiss(id: string, reminder: Reminder): Promise<{ 
  success: boolean;
  reminder: Reminder;
}> {
  const [hours, minutes] = reminder.time.split(':').map(Number);
  const now = new Date();
  const todayAtReminderTime = new Date();
  todayAtReminderTime.setHours(hours, minutes, 0, 0);
  
  let newLastSentDate: string | null;
  
  // Check if we need to reset (un-dismiss)
  const today = new Date().toISOString().split('T')[0];
  if (reminder.lastSentDate && reminder.lastSentDate >= today) {
    // Already dismissed -> reset
    newLastSentDate = null;
  } else {
    // Not dismissed -> dismiss based on current time
    if (todayAtReminderTime <= now) {
      // Time already passed today -> dismiss for tomorrow
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      newLastSentDate = tomorrow.toISOString().split('T')[0];
    } else {
      // Time hasn't passed yet -> dismiss for today
      newLastSentDate = today;
    }
  }
  
  return apiRequest(`/api/reminders/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ lastSentDate: newLastSentDate }),
  });
}



export async function deleteReminder(id: string): Promise<{ success: boolean }> {
  return apiRequest(`/api/reminders/${id}`, {
    method: 'DELETE',
  });
}
