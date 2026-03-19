<template>
  <div class="overlay">
    <img class="game-logo" src="../assets/game_logo.png" />
    <img class="tournament-logo" src="../assets/tournament_logo.png" />
  </div>
</template>

<script setup>
// import { store } from "../store";
</script>

<style scoped>
.game-logo {
  position: absolute;
  left: 0;
  bottom: 0;
}

.tournament-logo {
  position: absolute;
  right: 0;
  bottom: 0;
}
</style>
