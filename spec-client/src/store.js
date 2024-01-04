import { reactive } from "vue";

const TEAMS = [
    "None",
    "Spectator",
    "Jinrai",
    "NSF",
];

const CLASSES = [
    "None",
    "Recon",
    "Assault",
    "Support",
];

const VETOSTAGES = [
    "Inactive",
    "CoinFlip",
    "FirstTeamBan",
    "SecondTeamBan",
    "SecondTeamPick",
    "FirstTeamPick",
    "RandomThirdMap",
    "CoinFlipResult",
];

const store = reactive({
    players: [],
    roundTimeLeft: 0,
    roundNumber: 0,
    jinraiScore: 0,
    nsfScore: 0,
    currentMap: "",
    observerTarget: 0,
    showOverlay: false,
    nsf: {},
    jinrai: {},
    vetoStage: "Inactive",
    vetoFirst: "Jinrai",
    vetoSecond: "NSF",
    vetoPool: [],
    vetoPicks: [],
});

const uidToPlayer = {};

function debounce(func, wait, immediate) {
    let timeout;
    return function () {
        const context = this, args = arguments;
        const later = function () {
            timeout = null;
            if (!immediate) func.apply(context, args);
        };
        const callNow = immediate && !timeout;
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
        if (callNow) func.apply(context, args);
    };
}

async function getAvatarURLs() {
    const players = [...toLookUp];
    toLookUp.length = 0;
    const steamIds = players.map((player) => player.steamId, []).join();
    try {
        const res = process.env.NODE_ENV === 'development'
            ? await fetch('http://' + window.location.hostname + ':3000/avatar/' + steamIds)
            : await fetch('/avatar/' + steamIds);
        const data = await res.json();
        players.forEach((player) => {
            player.avatar = data[player.steamId];
        });
    } catch (e) {
        console.error("Error fetching avatars", e);
    }
}

const toLookUp = [];
const getAvatarURLsDebounced = debounce(getAvatarURLs, 100);

function getAvatarURL(player) {
    if (isNaN(parseInt(player.steamId)))
        return;

    toLookUp.push(player);
    getAvatarURLsDebounced();
}

async function handleMessage(data) {
    const type = data[0];
    const parts = data.slice(1).split(':');

    switch (type) {
        // * B: Round time left
        case 'B': {
            store.roundTimeLeft = parseInt(parts[0], 10);
            break;
        }
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
        // *G: Toggle ghost overtime
        case 'G': {
            store.ghostOvertime = parts[0] === '1';
            break;
        }
        // * H: Player was hurt
        case 'H': {
            const player = uidToPlayer[parts[0]];
            player.health = parts[1];

            break;
        }
        // * I: Initial child socket connect. Sends game and map
        case 'I': {
            console.log(`Connection to "${parts[4]}" established.`);
            document.title = parts[4];
            store.currentMap = parts[1];

            break;
        }
        // * K: Player died
        case 'K': {
            const player = uidToPlayer[parts[0]];
            player.isAlive = false;
            player.health = 0;
            player.activeWeapon = "";

            break;
        }
        // * L: List of veto maps that are used for vetos
        case 'L': {
            const num_maps = parts[0];
            let maps = [];
            for (let i = 1; i <= num_maps; ++i) {
                maps.push(parts[i]);
            }
            console.log('L -- Maps:\n' + maps);
            store.vetoPool = maps;
            store.vetoPicks = [];

            break;
        }
        // * M: Map changed
        case 'M': {
            store.currentMap = parts[0];
            store.jinraiScore = 0;
            store.nsfScore = 0;
            store.roundNumber = 0;

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
            store.roundNumber = +parts[0];
            store.jinraiScore = +parts[1];
            store.nsfScore = +parts[2];
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
        // Y: VetoStage has changed
        case 'Y': {
            const stage = VETOSTAGES[parts[0]];

            if (stage == "CoinFlipResult") {
                const team = TEAMS[parts[1]];
                console.log('Y -- Stage: ' + stage + ' && Team: ' + team);
                store.vetoFirst = team;
                store.vetoSecond = team === "Jinrai" ? "NSF" : "Jinrai";
            }
            else {
                console.log('Y -- Stage: ' + stage);
            }

            if (stage === "Inactive") {
                // Wait 30 seconds before removing the panel
                setTimeout(() => store.vetoStage = stage, 60000);
            } else {
                store.vetoStage = stage;
            }

            break;
        }
        // Z: A veto map ban/pick has been decided
        case 'Z': {
            const stage = VETOSTAGES[parts[0]];
            const team = TEAMS[parts[1]];
            const map = parts[2];

            console.log('Z -- Stage: ' + stage + ' && Team: ' + team + ' && Map: ' + map);

            store.vetoPicks.push({
                map,
                team,
                action: stage.endsWith('Ban') ? 'Ban' : 'Pick'
            });
            store.vetoPool = store.vetoPool.filter((m) => m !== map);

            break;
        }

        /* Example output from the veto flow:

            L -- Maps:
                    array of [nt_ballistrade_ctg,nt_bullet_tdm,nt_dawn_ctg,
                              nt_decom_ctg,nt_disengage_ctg,nt_dusk_ctg,
                              nt_engage_ctg,nt_ghost_ctg,nt_isolation_ctg]
            Y -- Stage: CoinFlip
            Y -- Stage: CoinFlipResult && Team: Jinrai
            Y -- Stage: FirstTeamBan
            Z -- Stage: FirstTeamBan && Team: Jinrai && Map: nt_dusk_ctg
            Y -- Stage: SecondTeamBan
            Z -- Stage: SecondTeamBan && Team: NSF && Map: nt_dawn_ctg
            Y -- Stage: SecondTeamPick
            Z -- Stage: SecondTeamPick && Team: NSF && Map: nt_decom_ctg
            Y -- Stage: FirstTeamPick
            Z -- Stage: FirstTeamPick && Team: Jinrai && Map: nt_isolation_ctg
            Y -- Stage: RandomThirdMap
            Z -- Stage: RandomThirdMap && Team: Spectator && Map: nt_ghost_ctg
            Y -- Stage: Inactive

        */
    }

    // console.log(data);
}

async function connect(ip) {
    const connectWs = () => {
        const ws = new WebSocket('ws://' + ip);
        ws.addEventListener('message', event => handleMessage(event.data));
        ws.addEventListener("close", async (event) => {
            store.players = [];
            if (!event.wasClean) {
                console.log("Lost connection to game server. Retrying...");
                connectWs();
            }
        });
    };
    connectWs();

    try {
        const localWs = process.env.NODE_ENV === 'development'
            ? new WebSocket(`ws://${window.location.hostname}:3000/state/${ip}`)
            : new WebSocket(`ws://${window.location.host}/state/${ip}`);
        localWs.addEventListener('message', event => {
            const state = JSON.parse(event.data);
            store.showOverlay = state.show;
            store.tournamentName = state.name;
            store.jinrai = state.jinrai;
            store.nsf = state.nsf;
        });
    } catch (e) {
        console.error("Error connecting to manager.", e);
    }

    try {
        const res = process.env.NODE_ENV === 'development'
            ? await fetch(`http://${window.location.hostname}:3000/state/${ip}`)
            : await fetch(`/state/${ip}`);
        const state = await res.json();
        store.showOverlay = state.show;
        store.tournamentName = state.name;
        store.jinrai = state.jinrai;
        store.nsf = state.nsf;
    } catch (e) {
        console.error("Error fetching match state", e);
    }

}

window.debug = {
    store
};

export {
    connect as connect,
    store as store,
};
