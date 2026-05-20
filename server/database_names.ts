

export const Collections = {
	printers: "printers",
	messages: "messages",
    users: "users",
    permissionRequests: "permissionRequests",
} as const;

export const PrinterFields = {
	onlineStatus: "onlineStatus",
	ownerUid: "ownerUid",
} as const;

export const MessageFields = {
	authorUid: "authorUid",
	destinationPid: "destinationPid",
	authorName: "authorName",
	sentTimestamp: "sentTimestamp",
	messageText: "messageText",
	images: "images",
	printed: "printed",
} as const;

export const permissionRequestFields = {
    pid: "pid",
    fromUid: "fromUid",
} as const;

export type FirestoreBytesLike = Uint8Array;
export type FirestoreTimestampLike = Date | { toDate(): Date };

export interface PrinterDocument {
	onlineStatus: boolean;
	ownerUid: string | null;
}

export interface MessageDocument {
	authorUid: string;
	destinationPid: string;
	authorName: string;
	sentTimestamp: FirestoreTimestampLike;
	messageText: string;
	images?: string[] | null;
	printed: boolean;
}

export const Paths = {
	printer: (pid: string) => [Collections.printers, pid] as const,
	printerMessages: (pid: string) =>
		[Collections.printers, pid, Collections.messages] as const,
} as const;

export const Schema = {
	collections: Collections,
	printerFields: PrinterFields,
	messageFields: MessageFields,
	paths: Paths,
} as const;
