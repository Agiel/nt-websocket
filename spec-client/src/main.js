import { createApp } from 'vue';
import App from './App.vue';
import { connect } from './store';

const IP = window.location.search
    ? new URLSearchParams(window.location.search).get('server')
    : window.location.hostname + ':12346';

connect(IP);
createApp(App).mount('#app');
