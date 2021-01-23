<template>
  <div id="round-counter">Round {{roundCount}}</div>
  <div id="container">
    <div id="jinrai">
      <PlayerPanel v-for="player in jinrai" :data="player" :key="player.userId"></PlayerPanel>
    </div>
    <div id="spacer"></div>
    <div id="nsf">
      <PlayerPanel v-for="player in nsf" :data="player" :key="player.userId"></PlayerPanel>
    </div>
  </div>
</template>

<script>
import { store } from './store'

import PlayerPanel from './components/PlayerPanel'

export default {
  name: 'App',
  computed: {
    players() {
      return store.players;
    },
    jinrai() {
      return this.players.filter((player) => player.team == "Jinrai");
    },
    nsf() {
      return this.players.filter((player) => player.team == "NSF");
    },
    roundCount() {
      return +store.roundNumber + 1;
    }
  },
  components: {
    PlayerPanel
  }
}
</script>

<style>
body {
    background-color: #666;
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
  margin-top: 400px;
  display: flex;
}

#spacer {
  flex: 1 1 auto;
}

#jinrai {
  text-align: left;
  /* color: rgba(192, 244, 196, 255); */
}

#jinrai .flex {
  flex-direction: row;
}

#jinrai .align {
  text-align: right;
}

#jinrai .bg-color {
  /* background-color: rgba(154, 255, 154, 0.8); */
  /* background-color: rgba(120, 180, 120, 0.8); */
  background: linear-gradient(90deg, rgba(120, 180, 120, 1), rgba(154, 255, 154, 1));
}

#nsf {
  text-align: right;
  /* color: rgba(181, 216, 248, 255); */
}

#nsf .flex {
  flex-direction: row-reverse;
}

#nsf .align {
  text-align: left;
}

#nsf .bg-color {
  /* background-color: rgba(154, 205, 255, 0.8); */
  /* background-color: rgba(80, 130, 210, 0.8); */
    background: linear-gradient(-90deg, rgba(80, 130, 210, 0.8), rgba(154, 205, 255, 0.8));
}

#round-counter {
  margin-top: 120px;
  font-family: xscale;
  font-size: 28px;
  color: white;
}

#debug {
  margin-top: 100px;
}
</style>
