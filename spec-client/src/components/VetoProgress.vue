<template>
    <div class="veto-progress" v-if="store.vetoStage !== 'Inactive'">
        <div class="veto-progress-container">
            <div class="veto-stage">{{ title }}</div>
            <div class="veto-picks">
                <div
                    class="veto-pick-container"
                    v-for="pick in store.vetoPicks"
                    :key="pick.map"
                    :class="pick.team.toLowerCase()"
                >
                    <span class="action" :class="pick.action.toLowerCase()">{{
                        getSymbol(pick)
                    }}</span>
                    <span
                        class="map"
                        :class="[
                            { finished: isFinished },
                            pick.action.toLowerCase(),
                        ]"
                        >{{ pick.map }}</span
                    >
                    <span class="dummy"></span>
                </div>
            </div>
            <div class="veto-pool">
                <div
                    v-for="map in store.vetoPool"
                    :key="map"
                    :class="{ finished: isFinished }"
                >
                    {{ map }}
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { computed } from "vue";
import { store } from "../store";

const getSymbol = (pick) =>
    pick.team === "Spectator" ? "🎲" : pick.action === "Pick" ? "✓" : "✗";

const isFinished = computed(() => store.vetoStage === "RandomThirdMap");

const getTeamName = (team) =>
    team === "Jinrai" ? store.jinrai.tag : store.nsf.tag;

const title = computed(() => {
    switch (store.vetoStage) {
        case "CoinFlip":
            return "Flipping Coin...";
        case "CoinFlipResult":
            return `${getTeamName(store.vetoFirst)} Goes First!`;
        case "FirstTeamBan":
            return `${getTeamName(store.vetoFirst)} to Ban...`;
        case "SecondTeamBan":
            return `${getTeamName(store.vetoSecond)} to Ban...`;
        case "SecondTeamPick":
            return `${getTeamName(store.vetoSecond)} to Pick...`;
        case "FirstTeamPick":
            return `${getTeamName(store.vetoFirst)} to Pick...`;
        case "RandomThirdMap":
            return "Good Luck, Have Fun!";
        default:
            return store.vetoStage;
    }
});
</script>

<style>
.veto-progress {
    position: absolute;
    width: 1920px;
    left: 0;
    top: 250px;
    font-family: xscale;
    font-size: 24px;
    color: white;
    opacity: 0.9;
}

.veto-progress-container {
    display: inline-block;
    padding: 12px;
    border-radius: 6px;
    background-color: rgba(0, 0, 0, 0.2);
}

.veto-stage {
    font-size: 28px;
}

.veto-pool {
    margin-top: 24px;
    margin-bottom: 6px;
}

.veto-pool .finished {
    text-decoration: line-through;
    color: gray;
}

.veto-picks {
    margin-top: 24px;
}

.veto-pick-container {
    display: flex;
    justify-content: center;
}

.veto-pick-container.nsf {
    flex-direction: row-reverse;
}

.veto-picks .action,
.veto-picks .dummy {
    width: 32px;
    text-align: center;
}

.veto-picks .action.ban {
    color: red;
}

.veto-picks .action.pick {
    color: green;
}

.veto-picks .map.finished.ban {
    text-decoration: line-through;
    color: gray;
}
</style>
