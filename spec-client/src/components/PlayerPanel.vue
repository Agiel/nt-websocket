<template>
  <div class="player-panel flex" :class="{ 'dead-flash': !data.isAlive && !data.isSpawning }">
    <img class="avatar" :class="{ dead: !data.isAlive && !data.isSpawning }" :src="data.avatar">
    <img class="dead-icon" src="icons/dead.png" v-if="!data.isAlive && !data.isSpawning">
    <div class="info flex">
      <div class="health-bar-container flex">
        <div class="health-bar health-bar-dmg" :style="{ width: data.health + '%' }" v-if="!data.isSpawning"></div>
      </div>
      <div class="health-bar-container flex">
        <div class="health-bar bg-color" :style="{ width: data.health + '%' }" v-if="data.isAlive"></div>
      </div>
      <div class="name">{{data.name}}</div>
      <div class="health">{{health}}</div>
      <div class="class align">{{className}}</div>
      <div class="break"></div>
      <div class="stats">
        <img class="xp-icon" :src="'icons/' + rank + '.png'">
        <div class="xp">{{data.xp}}</div>
        <img class="deaths-icon" src="icons/skull.png">
        <div class="deaths">{{data.deaths}}</div>
      </div>
      <div class="spacer"></div>
      <img class="weapon-icon" v-if="data.isAlive && data.activeWeapon" :src="'icons/' + data.activeWeapon + '.png'">
    </div>
</div>
</template>

<script>
export default {
  name: 'PlayerPanel',
  props: {
    data: Object
  },
  computed: {
    health() {
      if (this.data.isAlive) {
        return this.data.health;
      } else {
        return "";
      }
    },
    className() {
      if (this.data.isAlive) {
        return this.data.class;
      } else if (this.data.isSpawning) {
        return "";
      } else {
        return "Dead";
      }
    },
    rank() {
      if (this.data.xp < 0) {
        return "ranklessdog"
      } else if (this.data.xp < 4) {
        return "private"
      } else if (this.data.xp < 10) {
        return "corporal"
      } else if (this.data.xp < 20) {
        return "sergeant"
      } else {
        return "lieutenant"
      }
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
.player-panel {
  position: relative;
  font-weight: bold;
  /* border: 1px solid black; */
  display: flex;
  overflow: hidden;
  margin: 2px 0;
  width: 420px;
  color: white;
  text-shadow: 1px 1px 2px #222;
  background-color: rgba(0,0,0,0.5);
  box-sizing: border-box;
}

.break {
  flex: 0 0 100%;
  height: 0;
}

.spacer {
  flex: 1 1 auto;
}

.avatar {
  width: 64px;
  height: 64px;
  flex: 0 0 auto;
  margin: 2px;
}

.dead {
  filter: sepia(100%) hue-rotate(310deg) saturate(600%) brightness(50%);
}

.dead-icon {
  position: absolute;
  height: 68px;
  padding: 2px;
  box-sizing: border-box;
}

.info {
  flex: 1 1 auto;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  box-sizing: border-box;
  padding: 6px 12px;
  position: relative;
  z-index: 10;
}

.name {
  font-size: 16px;
  flex: 1 0 160px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.class {
  width: 60px;
  font-size: 14px;
  color: #eee;
}

.health {
  width: 60px;
  color: #eee;
  text-align: center;
}

.health-bar-container {
  display: flex;
  position: absolute;
  z-index: -1;
  height: 100%;
  width: 100%;
  left: 0px;
  padding: 2px;
  box-sizing: border-box;
  filter: brightness(75%);
}

.health-bar {
  height: 50%;
  left: 0px;
}

.health-bar-dmg {
  background: none;
  background-color: rgba(255,0,0,0.5);
  transition: width 1s ease 0.2s;
}

.stats {
  display: flex;
  font-size: 16px;
  line-height: 22px;
  align-self: flex-end;
}

.xp-icon, .deaths-icon {
  height: 18px;
  margin: 0 6px;
  align-self: center;
}

.xp, .deaths {
  width: 36px;
  text-align: left;
}

.weapon {
  font-size: 12px;
  color: #ccc;
}

.weapon-icon {
  height: 22px;
  position: relative;
  top: 2px;
}

@keyframes onPlayerDead {
  0% {
    background-color: rgba(255,0,0,0.5);
  }
  100% {
    background-color: rgba(0,0,0,0.5);
  }
}

.dead-flash {
  animation: onPlayerDead 2s ease;
}

h3 {
  margin: 40px 0 0;
}
ul {
  list-style-type: none;
  padding: 0;
}
li {
  display: inline-block;
  margin: 0 10px;
}
a {
  color: #42b983;
}
</style>
