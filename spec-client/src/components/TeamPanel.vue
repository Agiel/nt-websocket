<template>
    <div class="info">
        <div class="spacer"></div>
        <div>
            <img class="logo" :src="'logos/' + team.logo" />
            <div class="score-container">
                <span class="score">{{ scoreFirst }}</span>
                <span class="score">{{ scoreSecond }}</span>
            </div>
        </div>
        <div class="name align">{{ team.name }}</div>
    </div>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
    team: Object,
});
const scoreFirst = computed(() => (props.team.score > 0 ? "■" : "□"));
const scoreSecond = computed(() => (props.team.score > 1 ? "■" : "□"));
</script>

<style scoped>
.info {
    height: 117px;
    display: inline-flex;
    align-items: center;
}

.spacer {
    flex: 0 0 120px;
}
.name {
    flex: 0 0 auto;
    margin: 40px;
    font-family: xscale;
    color: white;
    font-size: 36px;
    max-width: 500px;
}

.logo {
    height: 72px;
}

.score-container {
    display: flex;
    line-height: 20px;
    justify-content: center;
    color: white;
    opacity: 0.9;
    font-size: 32px;
    -webkit-text-stroke: white 1px;
}

.score {
    margin: 0 6px;
}
</style>
