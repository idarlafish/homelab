export interface UserNotification {
    id: string;
    time: string;           // "09:00"
    message: string;
    timezone: string;
    lastSentDate?: string;  // "2026-01-16"
}

export interface UserScheduleConfig {
    chatId: number;
    enabled: boolean;
    notifications: UserNotification[];
}
