<template>
    <div class="container">
        <TeamPanel class="jinrai" :team="jinrai"></TeamPanel>
        <TeamPanel class="nsf" :team="nsf"></TeamPanel>
    </div>
</template>

<script setup>
import { computed } from "vue";
import TeamPanel from "./TeamPanel";
import { store } from "../store";

const jinrai = computed(() => store.jinrai);
const nsf = computed(() => store.nsf);
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
</style>

<style>
.jinrai .score-container {
    flex-direction: row-reverse;
}
</style>
