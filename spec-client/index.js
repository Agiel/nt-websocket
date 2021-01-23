const express = require('express');
//const cors = require('cors');
const http = require('http');
const { key } = require('./key');
const app = express();
const port = 3000;

// Look up the same steamID at most once per day
const CACHE_TIME = 1000 * 60 * 60 * 24;

app.use('/overlay', express.static('dist'));
//app.use(cors());

const avatarCache = {};

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

app.listen(port, () => {
  console.log(`Server listening at http://localhost:${port}`);
});
