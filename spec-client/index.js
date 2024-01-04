const express = require('express');
const ws = require('ws');
const cors = require('cors');
const http = require('http');
const { key } = require('./key');
const app = express();

const port = 3000;

// Look up the same steamID at most once per day
const CACHE_TIME = 1000 * 60 * 60 * 24;

app.use('/overlay', express.static('dist'));
app.use(cors());
app.use(express.json());

const avatarCache = {};

const overlayStateTemplate = {
    show: true,
    name: 'Winter Warzone 2024',
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

const serverMap = {};
const serverList = [
    ['bonAHNSa.com', '74.91.123.81', '27015', '12346'],
    ['sweaty and tryhard', '185.107.96.11', '27015', '12346'],
    ['baux.site', '128.140.0.50', '27015', '12346'],
    // ['Agiel\'s', '98.128.173.190', '27015', '12346'],
    ['Agiel\'s', '192.168.1.128', '27015', '12346'],

].map((server) => {
    const serverInfo = {
        overlayState: {
            ...structuredClone(overlayStateTemplate),
            serverName: server[0],
            serverAddress: `${server[1]}:${server[2]}`,
            overlayAddress: `${server[1]}:${server[3]}`,
        },
        wsServer: new ws.Server({
            noServer: true,
            clientTracking: true
        })
    };
    serverMap[serverInfo.overlayState.overlayAddress] = serverInfo;
    return serverInfo;
});

app.get('/servers', (req, res) => {
    res.send(serverList.map(list => list.overlayState));
});

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
                try {
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
                } catch {}
                res.send(response);
            });
        });
    } else {
        res.send(response);
    }
});

function getOverlayState(server) {
    const overlayState = serverMap[server]?.overlayState;
    if (!overlayState) {
        throw new Error('Invalid server ' + JSON.stringify(server));
    }
    return overlayState;
}

app.get('/state/:server', (req, res) => {
    const overlayState = getOverlayState(req.params.server);
    res.send(overlayState);
});

app.post('/state/:server', (req, res) => {
    const overlayState = getOverlayState(req.params.server);

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
        };
    }
    const nsf = req.body.nsf;
    if (typeof nsf == 'object') {
        overlayState.nsf = {
            name: nsf.name ?? overlayState.nsf.name,
            tag: nsf.tag ?? overlayState.nsf.tag,
            logo: nsf.logo ?? overlayState.nsf.logo,
            score: nsf.score ?? overlayState.nsf.score
        };
    }

    res.send(overlayState);

    serverMap[req.params.server].wsServer.clients.forEach(ws => ws.send(JSON.stringify(overlayState)));
});

const server = app.listen(port, () => {
    console.log(`Server listening at http://localhost:${port}`);
});

server.on('upgrade', (req, socket, head) => {
    if (req.url.startsWith('/state')) {
        const server = req.url.slice(req.url.lastIndexOf('/') + 1);
        const wsServer = serverMap[server]?.wsServer;
        if (!wsServer) {
            console.log('Invalid server ' + JSON.stringify(server));
            socket.destroy();
            return;
        }
        wsServer.handleUpgrade(req, socket, head, socket => {
            wsServer.emit('connection', socket, req);
        });
    } else {
        socket.destroy();
    }
});
