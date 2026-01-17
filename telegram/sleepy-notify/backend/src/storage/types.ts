export interface UserNotification {
  id: string;
  time: string;
  message: string;
  timezone: string;
  lastSentDate: string | null;
}

export interface UserScheduleConfig {
  chatId: number;
  enabled: boolean;
  notifications: UserNotification[];
}

export interface NotificationJob {
  userId: number;
  chatId: number;
  notification: UserNotification;
}
