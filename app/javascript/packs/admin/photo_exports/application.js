/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add  to the appropriate
// layout file, like app/views/layouts/application.html.erb
import Vue from 'vue'
import { ClientTable } from 'vue-tables-2';
Vue.use(ClientTable);
import photoExportsForm from '../../../views/admin/photo_exports/form.vue'
import photoExportsList from '../../../views/admin/photo_exports/list.vue'


document.addEventListener('DOMContentLoaded', () => {
  window.photoExport = new Vue({
    el: '#app',
    data(){
      return{
        newExport: null
      }
    },
    components: {
      photoExportsForm,
      photoExportsList
    },
    methods: {
      addPhotoItem(obj){
        this.newExport = obj;
      }
    }
  });
});






