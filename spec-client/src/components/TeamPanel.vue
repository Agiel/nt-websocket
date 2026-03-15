<template>
  <div class="info">
    <div class="spacer"></div>
    <!-- <div class="score-container">
            {{ props.score }}
        </div> -->
    <div class="maps-container">
      <span class="score" :class="{ filled: scoreSecond }">■</span>
      <span class="score" :class="{ filled: scoreFirst }">■</span>
    </div>
    <img class="logo" :src="'logos/' + team.logo" />
    <div v-if="team.name" class="name align">{{ team.name }}</div>
  </div>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  team: Object,
  score: Number,
});
const scoreFirst = computed(() => props.team.score > 0);
const scoreSecond = computed(() => props.team.score > 1);
</script>

<style scoped>
.info {
  height: 76px;
  display: inline-flex;
  align-items: start;
}

.spacer {
  flex: 0 0 130px;
}

.name {
  flex: 0 0 auto;
  margin-inline: 4px;
  margin-block: 4px;
  font-family: xscale;
  color: white;
  background-color: rgba(0, 0, 0, 0.5);
  border-radius: 8px;
  padding-inline: 20px;
  padding-bottom: 10px;
  font-size: 36px;
  max-width: 500px;
}

.logo {
  height: 72px;
  border-radius: 4px;
  margin: 4px;
}

.score-container {
  font-family: xscale;
  font-size: 48px;
  color: white;
  margin: 24px;
}

.maps-container {
  display: flex;
  flex-direction: column;
  height: 54px;
  line-height: 20px;
  justify-content: space-evenly;
  color: white;
  opacity: 0.9;
  font-size: 32px;
  -webkit-text-stroke: white 1px;
  margin-inline: 12px;
}

.score {
  opacity: 0.33;
}

.score.filled {
  opacity: 1;
}
</style>
