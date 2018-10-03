/* eslint no-console:0 */
import Vue from 'vue'
import { ClientTable } from 'vue-tables-2';
Vue.use(ClientTable);
import PhotoExport from './PhotoExport.vue'

document.addEventListener('DOMContentLoaded', () => {
  window.photoExport = new Vue({
    el: '#app',
    components: {
      'photo-export': PhotoExport,
    },
  });
});






