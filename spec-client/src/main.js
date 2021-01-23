import { createApp } from 'vue'
import App from './App.vue'
import { connect } from './store'

const IP = '5.135.160.152:12346'
//const IP = window.location.hostname + ':12346'

connect('ws:/' + IP)
createApp(App).mount('#app')
