# Server Setup and Usage

This guide explains how to:
- set up and run the server
- connect to the server IP address
- get messages with the GET route
- send messages with the POST route

## 1. Set up the server

From the project root, go into the server folder:

    cd /Users/lukemcfall/spr26-Team-20/server

Install dependencies:

    npm install

Run the server in development mode:

    npm run dev

You should see startup logs like:
- Server running on http://localhost:3000
- Server also available at http://YOUR_LOCAL_IP:3000

If you want a production build:

    npm run build
    npm start

## 2. Connect to the IP address

When the server starts, it prints one or more local IPv4 addresses.
Use one of those addresses from another device on the same Wi-Fi or local network.

Example:
- If the server prints http://192.168.1.24:3000
- Then use that base URL from your app or test requests.

Important:
- Both devices must be on the same local network.
- macOS firewall settings may need to allow incoming connections for Node.
- Port 3000 must be open and not blocked.

## 3. Get information with the GET route

Route:
- GET /messages?pid=YOUR_PID

Example request:

    curl "http://192.168.1.24:3000/messages?pid=printer-123"

Possible responses:
- 200 OK with a JSON array of messages for that pid.
- 404 Message not found if no messages exist for that pid.

Note:
- After a successful GET, the server deletes messages for that pid.
- A second GET for the same pid may return 404 unless new messages were posted.

## 4. Post a message with the POST route

Route:
- POST /send?pid=YOUR_PID

Required JSON body fields:
- uid
- message

Example request:

    curl -X POST "http://192.168.1.24:3000/send?pid=printer-123" \
      -H "Content-Type: application/json" \
      -d '{"uid":"user-42","message":"Print this file"}'

Expected response:
- 201 Message sent

What gets stored:
- id: from uid
- message: from message
- timestamp: server timestamp
- status: pending

## Quick flow test

1. Send a message with POST /send.
2. Fetch it with GET /messages for the same pid.
3. Fetch again to confirm the queue was cleared.

## File references

- Server routes and behavior: [server/server.ts](server/server.ts)
- This documentation: [docs/server-setup.md](docs/server-setup.md)
