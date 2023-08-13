<template>
    <div>
        <div class="container">
            <div class="infomask"></div>
            <div class="mapname">
                {{ store.currentMap }}
            </div>
            <TeamPanel
                class="jinrai"
                :team="store.jinrai"
                :score="store.jinraiScore"
            ></TeamPanel>
            <TeamPanel
                class="nsf"
                :team="store.nsf"
                :score="store.nsfScore"
            ></TeamPanel>
        </div>
    </div>
</template>

<script setup>
import TeamPanel from "./TeamPanel";
import { store } from "../store";
</script>

<style scoped>
.container {
    position: absolute;
    top: 0;
    left: 0;
    width: 1920px;
}

.jinrai,
.nsf {
    width: 50%;
}

.jinrai {
    flex-direction: row-reverse;
}

.infomask {
    z-index: -1;
    position: absolute;
    top: 0;
    right: -60px;
    width: 530px;
    height: 117px;
    background-image: linear-gradient(to left, black 80%, rgba(0, 0, 0, 0));
    transform: skew(45deg);
}

.mapname {
    position: absolute;
    top: 16px;
    right: 20px;
    font-family: xscale;
    font-size: 18px;
    color: white;
    opacity: 0.8;
}
</style>
