export const Collections = {
    printers: "printers",
    messages: "messages",
    users: "users",
    permissionRequests: "permissionRequests",
};
export const PrinterFields = {
    onlineStatus: "onlineStatus",
    ownerUid: "ownerUid",
};
export const MessageFields = {
    authorUid: "authorUid",
    destinationPid: "destinationPid",
    authorName: "authorName",
    sentTimestamp: "sentTimestamp",
    messageText: "messageText",
    images: "images",
    printed: "printed",
};
export const permissionRequestFields = {
    pid: "pid",
    fromUid: "fromUid",
};
export const Paths = {
    printer: (pid) => [Collections.printers, pid],
    printerMessages: (pid) => [Collections.printers, pid, Collections.messages],
};
export const Schema = {
    collections: Collections,
    printerFields: PrinterFields,
    messageFields: MessageFields,
    paths: Paths,
};
//# sourceMappingURL=database_names.js.map