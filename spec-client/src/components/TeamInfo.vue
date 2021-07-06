<template>
    <div class="container">
        <TeamPanel class="jinrai" :team="jinrai"></TeamPanel>
        <TeamPanel class="nsf" :team="nsf"></TeamPanel>
    </div>
</template>

<script>
import TeamPanel from './TeamPanel'
import { store } from '../store'

export default {
    computed: {
        jinrai() {
            return store.jinrai;
        },
        nsf() {
            return store.nsf;
        }
    },
    components: {
        TeamPanel
    }
}
</script>

<style scoped>
.container {
    position: absolute;
    top: 0;
    left: 0;
    width: 1920px;
}

.jinrai, .nsf {
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
