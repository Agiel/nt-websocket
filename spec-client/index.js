const express = require('express');
const ws = require('ws');
const cors = require('cors');
const http = require('http');
const { key } = require('./key');
const app = express();

const port = 3002;

// Look up the same steamID at most once per day
const CACHE_TIME = 1000 * 60 * 60 * 24;

app.use('/overlay', express.static('dist'));
app.use(cors());
app.use(express.json());

const wsServer = new ws.Server({
    noServer: true,
    clientTracking: true
});

const avatarCache = {};

const overlayState = {
    show: true,
    name: 'Winter Warzone 2023',
    jinrai: {
        name: '',
        tag: 'Jinrai',
        logo: 'jinrai.png',
        score: 0
    },
    nsf: {
        name: '',
        tag: 'NSF',
        logo: 'nsf.png',
        score: 0
    }
};

app.get('/avatar/:steamIds', (req, res) => {
    const steamIds = req.params.steamIds.split(',');

    const response = {};
    const toLookUp = [];

    const now = Date.now();
    for (let id of steamIds) {
        const cached = avatarCache[id];
        if (cached != null && now - cached.timestamp < CACHE_TIME) {
            response[id] = cached.avatar;
        } else {

            toLookUp.push(id);
        }
    }

    if (toLookUp.length > 0) {
        http.get('http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=' + key + '&steamids=' + toLookUp.join(), (resp) => {
            let data = '';

            resp.on('data', (chunk) => {
                data += chunk;
            });

            resp.on('end', () => {
                const json = JSON.parse(data);
                if (json != null && json.response != null && json.response.players != null) {
                    for (let player of json.response.players) {
                        avatarCache[player.steamid] = {
                            timestamp: now,
                            avatar: player.avatarmedium,
                        };
                        response[player.steamid] = player.avatarmedium;
                    }
                }
                res.send(response);
            });
        });
    } else {
        res.send(response);
    }
});

app.get('/state', (req, res) => {
    res.send(overlayState);
});

app.post('/state', (req, res) => {
    if (typeof req.body.show == 'boolean') {
        overlayState.show = req.body.show;
    }

    if (typeof req.body.name == 'string') {
        overlayState.name = req.body.name;
    }

    const jinrai = req.body.jinrai;
    if (typeof jinrai == 'object') {
        overlayState.jinrai = {
            name: jinrai.name ?? overlayState.jinrai.name,
            tag: jinrai.tag ?? overlayState.jinrai.tag,
            logo: jinrai.logo ?? overlayState.jinrai.logo,
            score: jinrai.score ?? overlayState.jinrai.score
        }
    }
    const nsf = req.body.nsf;
    if (typeof nsf == 'object') {
        overlayState.nsf = {
            name: nsf.name ?? overlayState.nsf.name,
            tag: nsf.tag ?? overlayState.nsf.tag,
            logo: nsf.logo ?? overlayState.nsf.logo,
            score: nsf.score ?? overlayState.nsf.score
        }
    }

    res.send(overlayState);

    wsServer.clients.forEach(ws => ws.send(JSON.stringify(overlayState)));
});

const server = app.listen(port, () => {
  console.log(`Server listening at http://localhost:${port}`);
});

wsServer.on('connection', socket => {
    socket.on('message', message => console.log(message));
});

server.on('upgrade', (req, socket, head) => {
    if (req.url == '/state') {
        wsServer.handleUpgrade(req, socket, head, socket => {
            wsServer.emit('connection', socket, req);
        });
    } else {
        socket.destroy();
    }
});
