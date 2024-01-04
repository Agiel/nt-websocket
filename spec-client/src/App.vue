<template>
    <div class="app">
        <TournamentOverlay v-if="store.showOverlay"></TournamentOverlay>
        <TeamInfo></TeamInfo>
        <div id="round-info">
            <div id="round-counter">Round {{ store.roundNumber }}</div>
            <div id="round-timer" :class="{ glitch: store.ghostOvertime, layers: store.ghostOvertime }" :data-text="roundTimeLeft">{{ roundTimeLeft }}</div>
            <div id="round-overtime" class="glitch layers" :hidden="!store.ghostOvertime" data-text="Overtime">Overtime</div>
        </div>
        <div id="container">
            <div class="players jinrai">
                <PlayerPanel
                    v-for="player in jinrai"
                    :data="player"
                    :key="player.userId"
                    :highlight="player.clientId == store.observerTarget"
                ></PlayerPanel>
            </div>
            <div id="spacer"></div>
            <div class="players nsf">
                <PlayerPanel
                    v-for="player in nsf"
                    :data="player"
                    :key="player.userId"
                    :highlight="player.clientId == store.observerTarget"
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
const roundTimeLeft = computed(
    () =>
        `${Math.floor(store.roundTimeLeft / 60)}:${String(
            store.roundTimeLeft % 60
        ).padStart(2, "0")}`
);
</script>

<style>
body {
    background-color: #222;
    width: 1920px;
    height: 1080px;
    margin: 0;
}

.app {
    height: 100%;
}

#app {
    font-family: Verdana, Geneva, Tahoma, sans-serif;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    text-align: center;
    color: #2c3e50;
    box-sizing: border-box;
    padding: 12px;
    height: 100%;
}

#container {
    height: 100%;
    display: flex;
}

#spacer {
    flex: 1 1 auto;
}

.players {
    display: flex;
    flex-direction: column;
    justify-content: center;
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

#round-info {
    position: absolute;
    left: 0;
    top: 0;
    width: 1920px;
    margin-top: 32px;
    font-family: xscale;
    font-size: 24px;
    color: white;
    line-height: 0.75;
}

#round-timer {
    font-size: 46px;
}

#round-overtime {
    margin-top: 2px;
    font-size: 21px;
}

#debug {
    margin-top: 100px;
}

@font-face {
    font-family: xscale;
    src: url("assets/X-SCALE_.TTF");
}
</style>
