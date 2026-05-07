export declare const Collections: {
    readonly printers: "printers";
    readonly messages: "messages";
};
export declare const PrinterFields: {
    readonly onlineStatus: "onlineStatus";
    readonly ownerUid: "ownerUid";
};
export declare const MessageFields: {
    readonly authorUid: "authorUid";
    readonly destinationPid: "destinationPid";
    readonly authorName: "authorName";
    readonly sentTimestamp: "sentTimestamp";
    readonly messageText: "messageText";
    readonly images: "images";
    readonly printed: "printed";
};
export type FirestoreBytesLike = Uint8Array;
export type FirestoreTimestampLike = Date | {
    toDate(): Date;
};
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
export declare const Paths: {
    readonly printer: (pid: string) => readonly ["printers", string];
    readonly printerMessages: (pid: string) => readonly ["printers", string, "messages"];
};
export declare const Schema: {
    readonly collections: {
        readonly printers: "printers";
        readonly messages: "messages";
    };
    readonly printerFields: {
        readonly onlineStatus: "onlineStatus";
        readonly ownerUid: "ownerUid";
    };
    readonly messageFields: {
        readonly authorUid: "authorUid";
        readonly destinationPid: "destinationPid";
        readonly authorName: "authorName";
        readonly sentTimestamp: "sentTimestamp";
        readonly messageText: "messageText";
        readonly images: "images";
        readonly printed: "printed";
    };
    readonly paths: {
        readonly printer: (pid: string) => readonly ["printers", string];
        readonly printerMessages: (pid: string) => readonly ["printers", string, "messages"];
    };
};
//# sourceMappingURL=database_names.d.ts.map