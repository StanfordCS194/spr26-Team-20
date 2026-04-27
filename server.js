// @ts-check
import express from 'express';
const app = express();
const port = 3000;
app.use(express.json());
var messages = {};
//POST message route
app.post('/send', (req, res) => {
    const pid = req.query.pid;
    const message = req.body.message;
    const uid = req.body.uid;
    const newMessage = {
        id: uid,
        message: message,
        timestamp: new Date(),
        status: 'pending'
    };
    if (messages[pid]) {
        messages[pid].push(newMessage);
    }
    else {
        messages[pid] = [newMessage];
    }
    res.status(201);
});
//GET messages route
app.get('/messages', (req, res) => {
    const pid = req.query.pid;
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
});
//# sourceMappingURL=server.js.map