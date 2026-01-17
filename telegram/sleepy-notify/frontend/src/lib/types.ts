export interface Reminder {
  id: string;
  time: string;
  message: string;
  timezone: string;
  lastSentDate: string | null;
}

export interface RemindersResponse {
  enabled: boolean;
  reminders: Reminder[];
}

export interface CreateReminderRequest {
  time: string;
  message: string;
  timezone: string;
}
