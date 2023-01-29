<template>
    <div class="overlay">
        <img class="overlay-image" src="../assets/overlay.png">
        <div class="tournament-name">{{tournamentName}}</div>
    </div>
</template>

<script>
import { store } from '../store'

export default {
    computed: {
        tournamentName: () => store.tournamentName,
    }
}
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
