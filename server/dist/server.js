// @ts-check
import express from "express";
import cors from "cors";
import { networkInterfaces } from "node:os";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { Collections, PrinterFields } from "./database_names.js";
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const envDir = join(__dirname, "env");
const envFiles = readdirSync(envDir).filter(file => file.endsWith('.json'));
const envFile = envFiles[0];
if (!envFile) {
    throw new Error("No JSON files found in env directory");
}
const serviceAccountPath = join(envDir, envFile);
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
const adminApp = initializeApp({
    credential: cert(serviceAccount),
});
const db = getFirestore(adminApp);
const app = express();
const port = Number(process.env.PORT) || 3000;
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type'],
}));
app.use(express.json());
var messages = {};
app.post("/send", (req, res) => {
    const pid = req.query.pid;
    const body = req.body;
    console.log(`Received request to send message to pid ${pid} with body:`, body);
    if (!pid || !body.authorUid) {
        res
            .status(400)
            .send("Missing required fields: pid, authorUid, messageText");
        return;
    }
    const newMessage = {
        authorUid: body.authorUid,
        destinationPid: pid,
        authorName: body.authorName,
        sentTimestamp: new Date(),
        messageText: body.messageText,
        images: body.images ?? [],
        printed: false,
    };
    db.collection(Collections.printers).doc(pid).collection(Collections.messages).add(newMessage)
        .then(() => {
        console.log(`Message for pid ${pid} added to Firestore`);
        res.status(201).send("Message sent");
    })
        .catch((error) => {
        console.error("Error adding message to Firestore", error);
        res.status(500).send("Failed to send message");
    });
    console.log(`Received message for pid ${pid}: ${body.messageText}`);
});
//GET messages route
app.get("/messages", async (req, res) => {
    const pid = req.query.pid;
    try {
        const querySnapshot = await db
            .collection(Collections.printers)
            .doc(pid)
            .collection(Collections.messages)
            .get();
        if (querySnapshot.docs.length === 0) {
            res.status(200).send("Message not found");
            return;
        }
        const unprintedDocs = querySnapshot.docs.filter((doc) => !doc.data().printed);
        const outputMessages = unprintedDocs.map((doc) => {
            const data = doc.data();
            return {
                authorUid: data.authorUid,
                destinationPid: data.destinationPid,
                authorName: data.authorName,
                sentTimestamp: data.sentTimestamp instanceof Date
                    ? data.sentTimestamp
                    : data.sentTimestamp.toDate(),
                messageText: data.messageText,
                images: data.images ?? [],
                printed: data.printed,
            };
        });
        // Mark returned messages as printed in Firestore so they aren't re-sent.
        if (unprintedDocs.length > 0) {
            const batch = db.batch();
            for (const doc of unprintedDocs) {
                batch.update(doc.ref, { printed: true });
            }
            await batch.commit();
        }
        res.json(outputMessages);
    }
    catch (error) {
        console.error("Failed to fetch messages", error);
        res.status(500).send("Failed to fetch messages");
    }
});
/**
 * PRINTER SETUP / MAINTENANCE ROUTES
 */
app.get("/status", async (req, res) => {
    const pid = req.query.pid;
    if (!pid) {
        res.status(400).send("Missing required field: pid");
        return;
    }
    try {
        const printerDoc = await db.collection(Collections.printers).doc(pid).get();
        if (!printerDoc.exists) {
            res.status(404).send("Printer not found");
            return;
        }
        const printerData = printerDoc.data();
        const isOnline = printerData?.[PrinterFields.onlineStatus] ?? false;
        if (isOnline) {
            res.status(200).json({ status: "Printer is online" });
            return;
        }
        res.status(503).json({ status: "Printer is offline" });
    }
    catch (error) {
        console.error("Failed to fetch printer status", error);
        res.status(500).send("Failed to fetch printer status");
    }
});
app.post("/setup", async (req, res) => {
    let pid = req.query.pid;
    let uid = req.body.uid;
    const printerDoc = await db.collection(Collections.printers).doc(pid).get();
    //First we need to check if the printer is already owned.
    if (printerDoc.exists) {
        const printerData = printerDoc.data();
        const owner_uid = printerData?.ownerUid ?? null;
        if (owner_uid != null) {
            res.status(403).send("Printer is already owned by another user");
            return;
        }
    }
    await db.collection(Collections.printers).doc(pid).set({
        ownerUid: uid,
        onlineStatus: false,
    }, { merge: true });
    const userDoc = await db.collection(Collections.users).doc(uid).get();
    const userData = userDoc.data();
    //Next we want to assign this pid to to the uid
    const ownedPids = userData?.ownedPids ?? [];
    ownedPids.push(pid);
    await db.collection(Collections.users).doc(uid).update({
        ownedPids: ownedPids,
    });
    res.status(200).send("Printer setup complete");
});
/*
* PERMISSION ROUTE
*/
app.post("/send-permission-request", async (req, res) => {
    let pid = req.query.pid;
    let uid = req.body.fromUid;
    var currentRequests = await db
        .collection(Collections.permissionRequests)
        .doc(pid)
        .get();
    var requestList = [];
    if (currentRequests.exists) {
        var currentData = currentRequests.data();
        if (currentData) {
            requestList = currentData.fromUid;
            requestList.push(uid);
        }
    }
    else {
        requestList.push(uid);
    }
    await db.collection(Collections.permissionRequests).doc(pid).set({
        fromUid: requestList,
    });
    res.status(200).send("Permission request sent");
});
app.get("/get-permission-requests", async (req, res) => {
    let pid = req.query.pid;
    db.collection(Collections.permissionRequests)
        .doc(pid)
        .get()
        .then((doc) => {
        if (!doc.exists) {
            res.status(404).send("No permission requests found for this printer");
            return;
        }
        var data = doc.data();
        var requestList = [];
        if (data) {
            requestList = data.fromUid;
        }
        res.status(200).json({ fromUid: requestList });
    })
        .catch((error) => {
        console.error("Error fetching permission requests", error);
        res.status(500).send("Failed to fetch permission requests");
    });
});
app.post("/accept-permission-request", async (req, res) => {
    let ownersUid = req.body.ownersUid;
    let pid = req.body.pid;
    let requestersUid = req.body.requestersUid;
    //First we need to check if the ownerUid is actually the owner of this printer.
    let userDoc = await db.collection(Collections.users).doc(ownersUid).get();
    if (!userDoc.exists) {
        res.status(404).send("Owner user not found");
        return;
    }
    //Check if the owner actually owns this printer
    let userData = userDoc.data();
    let ownedPids = [];
    if (userData && userData.ownedPids) {
        ownedPids = userData.ownedPids;
        if (!ownedPids.includes(pid)) {
            res.status(403).send("You do not have permission to accept requests for this printer");
            return;
        }
    }
    let request = await db.collection(Collections.permissionRequests).doc(pid).get();
    if (!request.exists) {
        res.status(404).send("No permission requests found for this printer");
        return;
    }
    //Check if the requester is actually in the list of permission requests for this printer.
    let requestData = request.data();
    let fromUidList = [];
    console.log("Request data:", requestData);
    if (requestData && requestData.fromUid) {
        fromUidList = requestData.fromUid;
        if (!fromUidList.includes(requestersUid)) {
            res.status(404).send("This user did not request permission for this printer");
            return;
        }
        // Remove the accepted requester from pending permission requests
        const updatedFromUidList = fromUidList.filter((pendingUid) => pendingUid !== requestersUid);
        // If there are no more pending requests, delete the permission request document; otherwise, update it with the remaining requests
        if (updatedFromUidList.length === 0) {
            await db.collection(Collections.permissionRequests).doc(pid).delete();
        }
        else {
            await db.collection(Collections.permissionRequests).doc(pid).update({
                fromUid: updatedFromUidList,
            });
        }
    }
    let requesterDoc = await db.collection(Collections.users).doc(requestersUid).get();
    if (!requesterDoc.exists) {
        res.status(404).send("Requester user not found");
        return;
    }
    //Add this printer to the requesters list of printers they have access to.
    let requesterData = requesterDoc.data();
    let friendedPids = [];
    if (requesterData && requesterData.friendedPids) {
        friendedPids = requesterData.friendedPids;
    }
    friendedPids.push(pid);
    await db.collection(Collections.users).doc(requestersUid).update({
        friendedPids: friendedPids,
    });
    res.status(200).send("Permission request accepted");
});
app.post("/reject-permission-request", async (req, res) => {
    let ownersUid = req.body.ownersUid;
    let pid = req.body.pid;
    let requestersUid = req.body.requestersUid;
    //First we need to check if the ownerUid is actually the owner of this printer.
    let userDoc = await db.collection(Collections.users).doc(ownersUid).get();
    if (!userDoc.exists) {
        res.status(404).send("Owner user not found");
        return;
    }
    //Check if the owner actually owns this printer
    let userData = userDoc.data();
    let ownedPids = [];
    if (userData && userData.ownedPids) {
        ownedPids = userData.ownedPids;
        if (!ownedPids.includes(pid)) {
            res.status(403).send("You do not have permission to reject requests for this printer");
            return;
        }
    }
    let request = await db.collection(Collections.permissionRequests).doc(pid).get();
    if (!request.exists) {
        res.status(404).send("No permission requests found for this printer");
        return;
    }
    //Check if the requester is actually in the list of permission requests for this printer.
    let requestData = request.data();
    let fromUidList = [];
    console.log("Request data:", requestData);
    if (requestData && requestData.fromUid) {
        fromUidList = requestData.fromUid;
        if (!fromUidList.includes(requestersUid)) {
            res.status(404).send("This user did not request permission for this printer");
            return;
        }
        // Remove the rejected requester from pending permission requests
        const updatedFromUidList = fromUidList.filter((pendingUid) => pendingUid !== requestersUid);
        // If there are no more pending requests, delete the permission request document; otherwise, update it with the remaining requests
        if (updatedFromUidList.length === 0) {
            await db.collection(Collections.permissionRequests).doc(pid).delete();
        }
        else {
            await db.collection(Collections.permissionRequests).doc(pid).update({
                fromUid: updatedFromUidList,
            });
        }
    }
    res.status(200).send("Permission request rejected");
});
/**
 * SERVER INFO ROUTE
 */
app.get("/server-info", (req, res) => {
    res.status(200).json({
        primaryUrl: process.env.PRIMARY_URL ?? `https://${req.get("host")}`,
    });
});
app.listen(port, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${port}`);
    const localIPs = getLocalIPv4Addresses();
    if (localIPs.length > 0) {
        for (const ip of localIPs) {
            console.log(`Server also available at http://${ip}:${port}`);
        }
    }
    else {
        console.log("No active external IPv4 address found.");
    }
});
function getLocalIPv4Addresses() {
    const nets = networkInterfaces();
    const addresses = new Set();
    for (const netInfoList of Object.values(nets)) {
        if (!netInfoList)
            continue;
        for (const netInfo of netInfoList) {
            if (netInfo.family === "IPv4" && !netInfo.internal) {
                addresses.add(netInfo.address);
            }
        }
    }
    return [...addresses];
}
app.post("/printers-list", async (req, res) => {
    const uid = req.body.uid;
    if (!uid) {
        res.status(400).send("Missing required field: uid");
        return;
    }
    try {
        const doc = await db.collection(Collections.users).doc(uid).get();
        if (!doc.exists) {
            res.status(404).send("User not found");
            return;
        }
        const data = doc.data();
        const ownedPids = data?.ownedPids ?? [];
        const friendedPids = data?.friendedPids ?? [];
        let printerIds = [...new Set([...ownedPids, ...friendedPids])];
        if (printerIds.length === 0) {
            printerIds = ['printer1'];
            console.log(`User ${uid} has no printers; returning fallback 'printer1'`);
        }
        res.status(200).json({ printers: printerIds });
    }
    catch (error) {
        console.error("Error fetching printer list", error);
        res.status(500).send("Failed to fetch printer list");
    }
});
//# sourceMappingURL=server.js.map