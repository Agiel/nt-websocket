<template>
    <div>
        <TournamentOverlay v-if="showOverlay"></TournamentOverlay>
        <TeamInfo></TeamInfo>
        <div id="round-counter">Round {{ roundCount }}</div>
        <div id="container">
            <div class="jinrai">
                <PlayerPanel
                    v-for="player in jinrai"
                    :data="player"
                    :key="player.userId"
                    :highlight="player.clientId == observerTarget"
                ></PlayerPanel>
            </div>
            <div id="spacer"></div>
            <div class="nsf">
                <PlayerPanel
                    v-for="player in nsf"
                    :data="player"
                    :key="player.userId"
                    :highlight="player.clientId == observerTarget"
                ></PlayerPanel>
            </div>
        </div>
        <VetoProgress></VetoProgress>
    </div>
</template>

<script setup>
import { computed } from "vue";
import { store } from "./store";
import PlayerPanel from "./components/PlayerPanel";
import TournamentOverlay from "./components/TournamentOverlay";
import TeamInfo from "./components/TeamInfo";
import VetoProgress from "./components/VetoProgress";

const players = computed(() =>
    store.players.sort((a, b) => +a.clientId - b.clientId)
);
const jinrai = computed(() =>
    players.value.filter((player) => player.team == "Jinrai")
);
const nsf = computed(() =>
    players.value.filter((player) => player.team == "NSF")
);
const roundCount = computed(() => +store.roundNumber + 1);
const observerTarget = computed(() => store.observerTarget);
const showOverlay = computed(() => store.showOverlay);
</script>

<style>
body {
    background-color: #222;
    width: 1920px;
}
#app {
    font-family: Verdana, Geneva, Tahoma, sans-serif;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    text-align: center;
    color: #2c3e50;
    padding: 12px;
}

#container {
    margin-top: 300px;
    display: flex;
}

#spacer {
    flex: 1 1 auto;
}

.jinrai {
    text-align: left;
    /* color: rgba(192, 244, 196, 255); */
}

.jinrai .flex {
    display: flex;
    flex-direction: row;
}

.jinrai .align {
    text-align: right;
}

.jinrai .bg-color {
    /* background-color: rgba(154, 255, 154, 0.8); */
    /* background-color: rgba(120, 180, 120, 0.8); */
    background: linear-gradient(
        90deg,
        rgba(120, 180, 120, 1),
        rgba(154, 255, 154, 1)
    );
}

.nsf {
    text-align: right;
    /* color: rgba(181, 216, 248, 255); */
}

.nsf .flex {
    display: flex;
    flex-direction: row-reverse;
}

.nsf .align {
    text-align: left;
}

.nsf .bg-color {
    /* background-color: rgba(154, 205, 255, 0.8); */
    /* background-color: rgba(80, 130, 210, 0.8); */
    background: linear-gradient(-90deg, rgb(72, 122, 202), rgb(143, 193, 243));
}

.nsf .weapon-icon {
    transform: scaleX(-1);
}

#round-counter {
    position: absolute;
    left: 0;
    top: 0;
    width: 1920px;
    margin-top: 48px;
    font-family: xscale;
    font-size: 28px;
    color: white;
}

#debug {
    margin-top: 100px;
}
</style>
