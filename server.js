// @ts-check
import express from "express";
import { networkInterfaces } from "node:os";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { Collections } from "./database_names.js";
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const serviceAccountPath = join(__dirname, "env", "printimate-44033-firebase-adminsdk-fbsvc-c045911551.json");
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));
const adminApp = initializeApp({
    credential: cert(serviceAccount),
});
const db = getFirestore(adminApp);
const app = express();
const port = 3000;
app.use(express.json());
var messages = {};
app.post("/send", (req, res) => {
    const pid = req.query.pid;
    const body = req.body;
    console.log(`Received request to send message to pid ${pid} with body:`, body);
    if (!pid || !body.messageText || !body.authorUid) {
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
        const messages = querySnapshot.docs.map((doc) => {
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
        //If no messages are found then we want to return a 404 error.
        if (messages.length === 0) {
            res.status(404).send("Message not found");
            return;
        }
        //We have all the messages this printer has recieved, we want to filter out the messages that have already been printed and return the rest.
        var outputMessage = [];
        for (const message of messages) {
            if (message.printed) {
                continue;
            }
            outputMessage.push(message);
        }
        res.json(outputMessage);
    }
    catch (error) {
        console.error("Failed to fetch messages", error);
        res.status(500).send("Failed to fetch messages");
    }
});
/**
 * PRINTER SETUP / MAINTENANCE ROUTES
 */
app.get("/status", (req, res) => {
    let pid = req.query.pid;
    var isOnline = true;
    /*
     * @Felipe: Get the online_status field from the database and store it in isOnline.
     */
    if (isOnline) {
        res.send(200).json({ status: "Printer is online" });
    }
    else {
        res.status(503).json({ status: "Printer is offline" });
    }
});
app.post("/setup", (req, res) => {
    let pid = req.query.pid;
    let uid = req.body.uid;
    //First we need to check if the printer is already owned.
    var owner_uid = null;
    /*
      @Felipe: Fetch the owner_uid field from the database and store it in ownerUid.
      */
    if (owner_uid != null) {
        res.status(403).send("Printer is already owned by another user");
        return;
    }
    //Next we want to assign this pid to to the uid
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
app.listen(port, () => {
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
//# sourceMappingURL=server.js.map