import { getInitData } from './telegram.ts';
import type { RemindersResponse, CreateReminderRequest, Reminder } from './types';

// const API_BASE = import.meta.env.DEV ? 'http://localhost:3000' : 'https://chan-intercrural-lissa.ngrok-free.dev';
const API_BASE = 'https://chan-intercrural-lissa.ngrok-free.dev';

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

export async function deleteReminder(id: string): Promise<{ success: boolean }> {
  return apiRequest(`/api/reminders/${id}`, {
    method: 'DELETE',
  });
}
