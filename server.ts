// @ts-check

import express from "express";
import type { Request, Response } from "express";
import cors from "cors";
import { networkInterfaces } from "node:os";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { Collections } from "./database_names.js";
import type { MessageDocument } from "./database_names.js";
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const envDir = join(__dirname, "env");
const envFiles = readdirSync(envDir).filter(file => file.endsWith('.json'));

if (envFiles.length === 0) {
  throw new Error("No JSON files found in env directory");
}

const serviceAccountPath = join(envDir, envFiles[0]);

const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, "utf-8"));

const adminApp = initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore(adminApp);

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

type Message = {
  authorUid: string;
  destinationPid: string;
  authorName: string;
  sentTimestamp: Date;
  messageText: string;
  images: string[];
  printed: boolean;

};

var messages: { [key: string]: Message[] } = {};

/**
 * MESSAGING FEATURES
 */

//POST message route
type SendMessageRequest = {
    authorUid: string;
    destinationPid: string;
    authorName: string;
    sentTimestamp: Date;
    messageText: string;
    images: string[];
}

app.post("/send", (req, res) => {
  const pid: string = req.query.pid as string;
  const body = req.body as SendMessageRequest;

  console.log(`Received request to send message to pid ${pid} with body:`, body);

  if (!pid || !body.messageText || !body.authorUid) {
    res
      .status(400)
      .send("Missing required fields: pid, authorUid, messageText");
    return;
  }

  const newMessage: MessageDocument = {
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
    .catch((error: any) => {
    console.error("Error adding message to Firestore", error);
    res.status(500).send("Failed to send message");
  });

  console.log(`Received message for pid ${pid}: ${body.messageText}`);


});

//GET messages route
app.get("/messages", async (req, res) => {
  const pid: string = req.query.pid as string;

  try {
    const querySnapshot = await db
      .collection(Collections.printers)
      .doc(pid)
      .collection(Collections.messages)
      .get();

    const messages: Message[] = querySnapshot.docs.map((doc: any) => {
      const data = doc.data() as MessageDocument;

      return {
        authorUid: data.authorUid,
        destinationPid: data.destinationPid,
        authorName: data.authorName,
        sentTimestamp:
          data.sentTimestamp instanceof Date
            ? data.sentTimestamp
            : data.sentTimestamp.toDate(),
        messageText: data.messageText,
        images: data.images ?? [],
        printed: data.printed,
      };
    });

    //If no messages are found then we want to return a 404 error.
    if (messages.length === 0) {
      res.status(200).send("Message not found");
      return;
    }

    //We have all the messages this printer has recieved, we want to filter out the messages that have already been printed and return the rest.
    var outputMessage : Message[] = [];
    for (const message of messages) {
        if(message.printed) {
            continue;
        }
      
        outputMessage.push(message);
    }

    res.json(outputMessage);
  } catch (error) {
    console.error("Failed to fetch messages", error);
    res.status(500).send("Failed to fetch messages");
  }
});

/**
 * PRINTER SETUP / MAINTENANCE ROUTES
 */

app.get("/status", (req, res) => {
  let pid = req.query.pid as string;

  var isOnline: boolean = true;
  /*
   * @Felipe: Get the online_status field from the database and store it in isOnline.
   */
  if (isOnline) {
    res.send(200).json({ status: "Printer is online" });
  } else {
    res.status(503).json({ status: "Printer is offline" });
  }
});

app.post("/setup", (req, res) => {
  let pid = req.query.pid as string;
  let uid = req.body.uid as string;

  //First we need to check if the printer is already owned.
  var owner_uid: string | null = null;
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
  let pid = req.query.pid as string;
  let uid = req.body.fromUid as string;

  var currentRequests = await db
    .collection(Collections.permissionRequests)
    .doc(pid)
    .get();

  var requestList: string[] = [];

  if (currentRequests.exists) {
    var currentData = currentRequests.data();
    if (currentData) {
      requestList = currentData.fromUid as string[];
      requestList.push(uid);
    }
  } else {
    requestList.push(uid);
  }

  await db.collection(Collections.permissionRequests).doc(pid).set({
    fromUid: requestList,
  });
  res.status(200).send("Permission request sent");
});

app.get("/get-permission-requests", async (req, res) => {
  let pid = req.query.pid as string;

  db.collection(Collections.permissionRequests)
    .doc(pid)
    .get()
    .then((doc) => {
      if (!doc.exists) {
        res.status(404).send("No permission requests found for this printer");
        return;
      }

      var data = doc.data();
      var requestList: string[] = [];
      if (data) {
        requestList = data.fromUid as string[];
      }

      res.status(200).json({ fromUid: requestList });
    })
    .catch((error) => {
      console.error("Error fetching permission requests", error);
      res.status(500).send("Failed to fetch permission requests");
    });
});

app.post("/accept-permission-request", async (req, res) => {
    let ownersUid = req.body.ownersUid as string;
    let pid = req.body.pid as string;
    let requestersUid = req.body.requestersUid as string;

    //First we need to check if the ownerUid is actually the owner of this printer.
    let userDoc = await db.collection(Collections.users).doc(ownersUid).get();
    if (!userDoc.exists) {
        res.status(404).send("Owner user not found");
        return;
    }

    //Check if the owner actually owns this printer
    let userData = userDoc.data();
    let ownedPids: string[] = [];
    if (userData && userData.ownedPids) {
        ownedPids = userData.ownedPids as string[];

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
    let fromUidList: string[] = [];
    console.log("Request data:", requestData);
    if (requestData && requestData.fromUid) {
        fromUidList = requestData.fromUid as string[];

        if (!fromUidList.includes(requestersUid)) {
            res.status(404).send("This user did not request permission for this printer");
            return;
        }

        // Remove the accepted requester from pending permission requests
        const updatedFromUidList = fromUidList.filter(
          (pendingUid) => pendingUid !== requestersUid
        );

        // If there are no more pending requests, delete the permission request document; otherwise, update it with the remaining requests
        if (updatedFromUidList.length === 0) {
          await db.collection(Collections.permissionRequests).doc(pid).delete();
        } else {
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
    let friendedPids: string[] = [];
    if (requesterData && requesterData.friendedPids) {
        friendedPids = requesterData.friendedPids as string[];
    }
    friendedPids.push(pid);
    await db.collection(Collections.users).doc(requestersUid).update({
        friendedPids: friendedPids,
    });

    res.status(200).send("Permission request accepted");
}); 

app.post("/reject-permission-request", async (req, res) => {
    let ownersUid = req.body.ownersUid as string;
    let pid = req.body.pid as string;
    let requestersUid = req.body.requestersUid as string;

    //First we need to check if the ownerUid is actually the owner of this printer.
    let userDoc = await db.collection(Collections.users).doc(ownersUid).get();
    if (!userDoc.exists) {
        res.status(404).send("Owner user not found");
        return;
    }

    //Check if the owner actually owns this printer
    let userData = userDoc.data();
    let ownedPids: string[] = [];
    if (userData && userData.ownedPids) {
        ownedPids = userData.ownedPids as string[];

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
    let fromUidList: string[] = [];
    console.log("Request data:", requestData);
    if (requestData && requestData.fromUid) {
        fromUidList = requestData.fromUid as string[];

        if (!fromUidList.includes(requestersUid)) {
            res.status(404).send("This user did not request permission for this printer");
            return;
        }

        // Remove the rejected requester from pending permission requests
        const updatedFromUidList = fromUidList.filter(
          (pendingUid) => pendingUid !== requestersUid
        );

        // If there are no more pending requests, delete the permission request document; otherwise, update it with the remaining requests
        if (updatedFromUidList.length === 0) {
          await db.collection(Collections.permissionRequests).doc(pid).delete();
        } else {
          await db.collection(Collections.permissionRequests).doc(pid).update({
            fromUid: updatedFromUidList,
          });
        }
    }

    res.status(200).send("Permission request rejected");
});





app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);

  const localIPs = getLocalIPv4Addresses();
  if (localIPs.length > 0) {
    for (const ip of localIPs) {
      console.log(`Server also available at http://${ip}:${port}`);
    }
  } else {
    console.log("No active external IPv4 address found.");
  }
});

function getLocalIPv4Addresses(): string[] {
  const nets = networkInterfaces();
  const addresses = new Set<string>();

  for (const netInfoList of Object.values(nets)) {
    if (!netInfoList) continue;

    for (const netInfo of netInfoList) {
      if (netInfo.family === "IPv4" && !netInfo.internal) {
        addresses.add(netInfo.address);
      }
    }
  }

  return [...addresses];
}
