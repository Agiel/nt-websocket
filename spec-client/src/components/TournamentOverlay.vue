<template>
    <div class="overlay">
        <img class="overlay-image" src="../assets/overlay.png" />
        <div class="tournament-name">{{ tournamentName }}</div>
    </div>
</template>

<script setup>
import { computed } from "vue";
import { store } from "../store";

const tournamentName = computed(() => store.tournamentName);
</script>

<style scoped>
.overlay {
    position: absolute;
    top: 0;
    left: 0;
}

.tournament-name {
    position: absolute;
    bottom: 28px;
    left: 118px;
    font-family: xscale;
    font-size: 42px;
    color: white;
    opacity: 0.9;
}
</style>
