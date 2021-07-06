import { reactive } from "vue";

const TEAMS = [
    "None",
    "Spectator",
    "Jinrai",
    "NSF",
]

const CLASSES = [
    "None",
    "Recon",
    "Assault",
    "Support",
]

const store = reactive({
    players: [],
    roundNumber: 0,
    observerTarget: 0,
    showOverlay: false,
    nsf: {},
    jinrai: {}
});

const uidToPlayer = {};

function debounce(func, wait, immediate) {
	var timeout;
	return function() {
		var context = this, args = arguments;
		var later = function() {
			timeout = null;
			if (!immediate) func.apply(context, args);
		};
		var callNow = immediate && !timeout;
		clearTimeout(timeout);
		timeout = setTimeout(later, wait);
		if (callNow) func.apply(context, args);
	};
}

async function getAvatarURLs(players) {
    const steamIds = players.map((player) => player.steamId, []).join();
    try {

        // const res = await fetch('http://' + window.location.hostname + ':3000/avatar/' + steamIds);
        const res = await fetch('/avatar/' + steamIds);
        const data = await res.json();
        while (players.length > 0) {
            const player = players.pop();
            player.avatar = data[player.steamId];
        }
    } catch (e) {
        while (players.length > 0) { players.pop() }
    }
}

const toLookUp = [];
const getAvatarURLsDebounced = debounce(getAvatarURLs, 100);

function getAvatarURL(player) {
    if (isNaN(parseInt(player.steamId)))
        return;

    toLookUp.push(player);
    getAvatarURLsDebounced(toLookUp);
}

async function handleMessage(data) {
    const type = data[0];
    const parts = data.slice(1).split(':');

    switch(type) {
        // * C: Player connected
        case 'C': {
            const player = reactive({
                userId: parts[0],
                clientId: parts[1],
                steamId: parts[2],
                team: TEAMS[parts[3]],
                isAlive: !!+parts[4],
                isSpawning: false,
                xp: parts[5],
                deaths: parts[6],
                health: parts[7],
                class: CLASSES[parts[8]],
                activeWeapon: parts[9].slice(7),
                name: parts[10],
            });

            if (!player.isAlive) {
                // Server reports dead players with hp 1, so set to 0
                player.health = 0;
            }

            uidToPlayer[player.userId] = player;
            store.players.push(player);

            getAvatarURL(player);

            break;
        }
        // * D: Player disconnected
        case 'D': {
            const userId = parts[0];
            const player = uidToPlayer[userId];
            if (!player) {
                return;
            }

            const idx = store.players.indexOf(player);
            if (idx > -1) {
                store.players.splice(idx, 1);
            }

            delete uidToPlayer[userId];

            break;
        }
        // * E: Player equipped weapon
        // * F: Player fired gun
        case 'F': {
            const player = uidToPlayer[parts[0]];
            player.isFiring = true;
            setTimeout(() => player.isFiring = false, 10);

            break;
        }
        // * H: Player was hurt
        case 'H': {
            const player = uidToPlayer[parts[0]];
            player.health = parts[1];

            break;
        }
        // * I: Initial child socket connect. Sends game and map
        // * K: Player died
        case 'K': {
            const player = uidToPlayer[parts[0]];
            player.isAlive = false;
            player.health = 0;
            player.activeWeapon = "";

            break;
        }
        // * N: Player changed his name
        case 'N': {
            const player = uidToPlayer[parts[0]];
            player.name = parts[1];

            break;
        }
        // * O: Observer target changed
        case 'O': {
            store.observerTarget = parts[0];
            break;
        }
        // * P: Player score changed
        case 'P': {
            const player = uidToPlayer[parts[0]];
            player.xp = parts[1];
            player.deaths = parts[2];

            break;
        }
        // * R: Round start
        case 'R':
            store.roundNumber = parts[0];
            store.players.forEach((player) => {
                player.isAlive = false;
                player.isSpawning = true;
                player.health = 0;
                player.activeWeapon = "";
            });

            break;
        // * S: Player spawned
        case 'S': {
            const player = uidToPlayer[parts[0]];
            player.class = CLASSES[parts[1]];

            if (player.class == "None") {
                // Player joined mid-round
                player.isAlive = false;
                player.health = 0;
            } else {
                player.isAlive = true;
                player.health = 100;
            }
            player.isSpawning = false;

            break;
        }
        // * T: Player changed team
        case 'T': {
            const player = uidToPlayer[parts[0]];
            player.team = TEAMS[parts[1]];

            break;
        }
        // * W: Player switched to weapon
        case 'W': {
            const player = uidToPlayer[parts[0]];
            player.activeWeapon = parts[1].slice(7);

            break;
        }
    }

    // console.log(data);
}

async function connect(ip) {
    const ws = new WebSocket(ip);
    ws.addEventListener('message', event => handleMessage(event.data));

    // const localWs = new WebSocket('ws://' + window.location.hostname + ':3000/state');
    const localWs = new WebSocket('ws://' + window.location.host + '/state');
    localWs.addEventListener('message', event => {
        const state = JSON.parse(event.data);
        store.showOverlay = state.show;
        store.jinrai = state.jinrai;
        store.nsf = state.nsf;
    });

    // const res = await fetch('http://' + window.location.hostname + ':3000/state');
    const res = await fetch('/state');
    const state = await res.json();
    store.showOverlay = state.show;
    store.jinrai = state.jinrai;
    store.nsf = state.nsf;
}


export {
    connect as connect,
    store as store,
}
