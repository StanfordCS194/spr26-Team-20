// @ts-check

import express from 'express';
import type { Request, Response } from 'express';
import { networkInterfaces } from 'node:os';

const app = express();
const port = 3000;

app.use(express.json());

type Message = {
    id: string;
    message: string;
    timestamp: Date;
    status: 'pending' | 'processing' | 'completed' | 'error';
}

var messages: { [key: string]: Message[] } = {}

//POST message route
app.post('/send', (req, res) => {
    const pid : string = req.query.pid as string;
    const message = req.body.message;
    const uid = req.body.uid;


    const newMessage: Message = {
        id: uid,
        message: message,
        timestamp: new Date(),
        status: 'pending'
    };

    if(messages[pid]){
        messages[pid].push(newMessage);
    } else {
        messages[pid] = [newMessage];
    }
    console.log(`Received message for pid ${pid}: ${message}`);

    res.status(201).send('Message sent');
});

//GET messages route
app.get('/messages', (req, res) => {
    const pid : string = req.query.pid as string;
    
    const message = messages[pid];

    if (message == undefined) {
        res.status(404).send('Message not found');
        return;
    }

    res.json(message);
    delete messages[pid];
});

app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);

    const localIPs = getLocalIPv4Addresses();
    if (localIPs.length > 0) {
        for (const ip of localIPs) {
            console.log(`Server also available at http://${ip}:${port}`);
        }
    } else {
        console.log('No active external IPv4 address found.');
    }
});

function getLocalIPv4Addresses(): string[] {
    const nets = networkInterfaces();
    const addresses = new Set<string>();

    for (const netInfoList of Object.values(nets)) {
        if (!netInfoList) continue;

        for (const netInfo of netInfoList) {
            if (netInfo.family === 'IPv4' && !netInfo.internal) {
                addresses.add(netInfo.address);
            }
        }
    }

    return [...addresses];
}