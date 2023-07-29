import { createApp } from 'vue';
import App from './App.vue';
import { connect } from './store';

const IP = window.location.hash
    ? window.location.hash.slice(1)
    : window.location.hostname + ':12346';

connect('ws://' + IP);
createApp(App).mount('#app');
