export interface UserNotification {
	id: string;
	time: string;
	message: string;
	timezone: string;
	lastSentDate: string | null;
}

export interface UserScheduleConfig {
	chatId: number;
	notifications: UserNotification[];
}

export interface NotificationJob {
	userId: number;
	chatId: number;
	notification: UserNotification;
}
