<template>
    <div class="panel-container flex">
        <div class="player-panel flex" :class="{
            'dead-flash': !data.isAlive && !data.isSpawning,
            highlight: highlight,
        }">
            <div class="avatar-container flex">
                <div class="avatar" :class="{ dead: !data.isAlive && !data.isSpawning }"
                    :style="{ 'background-image': 'url(' + data.avatar + ')' }"></div>
                <img class="dead-icon" src="icons/dead.svg" v-if="!data.isAlive && !data.isSpawning" />
                <div class="health">{{ health }}</div>
                <div class="round-kills align" v-if="data.roundKills > 0">{{ 'x' + data.roundKills }}</div>
            </div>
            <div class="info flex">
                <div class="health-bar-container flex">
                    <div class="health-bar health-bar-dmg" :style="{ width: data.health + '%' }" v-if="!data.isSpawning">
                    </div>
                </div>
                <div class="health-bar-container flex">
                    <div class="health-bar bg-color" :style="{ width: data.health + '%' }" v-if="data.isAlive"></div>
                </div>
                <div class="name">{{ data.name }}</div>
                <div class="class">{{ className }}</div>

                <div class="break"></div>
                <div class="stats">
                    <div class="icon-container">
                        <img class="xp-icon" :src="'icons/' + rank + '.svg'" />
                    </div>
                    <div class="xp">{{ data.xp }}</div>
                    <div class="icon-container">
                        <img class="deaths-icon" src="icons/skull.svg" />
                    </div>
                    <div class="deaths">{{ data.deaths }}</div>
                </div>
                <div class="spacer"></div>
                <div class="weapons-container align" v-if="data.isAlive">
                    <img v-for="weapon in equippedWeapons" :key="weapon" class="weapon-icon"
                        :class="{ [getWeaponType(weapon)]: true, active: data.activeWeapon === weapon }"
                        :src="'icons/' + weapon + '.svg'" />
                </div>
            </div>
        </div>
        <div class="muzzleflash" :class="{ firing: data.isFiring }"></div>
        <img class="ghost" :class="{ active: data.activeWeapon === 'ghost' }" v-if="data.isAlive && hasGhost"
            :src="'icons/ghost.svg'" />
    </div>
</template>

<script setup>
import { computed } from "vue";
import { getWeaponType } from "../store";

const props = defineProps({
    data: Object,
    highlight: Boolean,
});

const health = computed(() => {
    if (props.data.isAlive) {
        return props.data.health;
    } else {
        return "";
    }
});

const className = computed(() => (props.data.isAlive ? props.data.class : ""));

const rank = computed(() => {
    if (props.data.xp < 0) {
        return "ranklessdog";
    } else if (props.data.xp < 4) {
        return "private";
    } else if (props.data.xp < 10) {
        return "corporal";
    } else if (props.data.xp < 20) {
        return "sergeant";
    } else {
        return "lieutenant";
    }
});

const hasGhost = computed(() => props.data.equippedWeapons.has("ghost"));

const equippedWeapons = computed(() => [...props.data.equippedWeapons.values()].filter((w) => w !== 'ghost' && w !== 'knife').sort((a, b) =>
    getWeaponType(b).localeCompare(getWeaponType(a))
));
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
.player-panel {
    font-weight: bold;
    margin: 2px 0;
    /* padding: 2px; */
    width: 350px;
    color: white;
    text-shadow: 1px 1px 2px #222;
    background-color: rgba(0, 0, 0, 0.5);
    box-sizing: border-box;
    border-radius: 4px;
    overflow: hidden;
}

.player-panel.highlight {
    border: 2px solid rgba(255, 255, 255, 0.8);
    padding: 0;
}

.break {
    flex: 0 0 100%;
    height: 0;
}

.spacer {
    flex: 1 1 auto;
}

.avatar-container {
    position: relative;
    display: flex;
    flex: 0 0 auto;
    height: 64px;
    width: 66px;
}

.avatar {
    width: 64px;
    height: 64px;
    border-radius: 4px;
}

.dead {
    background-color: red;
    background-blend-mode: luminosity;
    filter: brightness(50%) contrast(150%);
}

.dead-icon {
    position: absolute;
    height: 64px;
    z-index: 100;
}

.info {
    flex: 1 1 auto;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    min-width: 0;
    box-sizing: border-box;
    padding: 4px 10px;
    position: relative;
    z-index: 10;
}

.name {
    font-size: 14px;
    flex: 1 0 160px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.class {
    font-size: 11px;
    color: #ddd;
    text-align: center;
}

.health {
    position: absolute;
    bottom: 2px;
    padding-inline: 2px;
    width: 100%;
    /* text-align: center; */
    text-shadow: 0 0 4px black;
}

.round-kills {
    box-sizing: border-box;
    z-index: 101;
    position: absolute;
    top: 2px;
    padding-inline: 2px;
    width: 100%;
    text-shadow: 0 0 4px black;
}

.health-bar-container {
    display: flex;
    position: absolute;
    z-index: -1;
    height: 100%;
    width: 100%;
    left: 0px;
    box-sizing: border-box;
    filter: brightness(75%);
}

.health-bar {
    height: 50%;
    left: 0px;
}

.health-bar-dmg {
    background: none;
    background-color: rgba(255, 0, 0, 0.5);
    transition: width 1s ease 0.2s;
}

.stats {
    display: flex;
    font-size: 14px;
    line-height: 22px;
    align-self: flex-end;
    align-items: center;
}

.icon-container {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 16px;
    width: 16px;
    margin-right: 6px;
}

.xp-icon,
.deaths-icon {
    max-height: 16px;
    max-width: 16px;
}

.xp,
.deaths {
    width: 18px;
    text-align: left;
    color: #ccc;
}

.xp {
    margin-right: 14px;
}

.weapons-container {
    width: 166px;
    margin-inline: -4px;
    white-space: nowrap;
}

.weapon-icon {
    box-sizing: border-box;
    max-height: 12px;
    max-width: 36px;
    position: relative;
    top: 4px;
    margin-inline-start: 6px;
    opacity: 0.5;
    transition: opacity 0.1s linear;
}

.weapon-icon.primary {
    max-height: 22px;
    max-width: 64px;
}

.weapon-icon.active {
    opacity: 1;
}

.muzzleflash {
    margin: 2px 0;
    border: solid 1px black;
    width: 2px;
    opacity: 0;
    background-color: white;
    transition: opacity 1s ease-out;
    box-shadow: 0 0 3px 0 white;
}

.muzzleflash.firing {
    opacity: 0.8;
    transition: opacity 0s;
}

.ghost {
    align-self: center;
    opacity: 0.6;
}

.ghost.active {
    opacity: 1;
}

@keyframes onPlayerDead {
    0% {
        background-color: rgba(255, 0, 0, 0.5);
    }

    100% {
        background-color: rgba(24, 0, 0, 0.5);
    }
}

.dead-flash {
    animation: onPlayerDead 2s ease;
    background-color: rgba(24, 0, 0, 0.5);
}
</style>
