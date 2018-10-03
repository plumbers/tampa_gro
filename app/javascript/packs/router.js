import Vue from 'vue';
import Router from 'vue-router';
import PhotoExport from '@src/admin/photo_exports/PhotoExport';

Vue.use(Router);

export default new Router({
  routes: [
    {
      path: '/',
      name: 'PhotoExport',
      component: PhotoExport,
    },
  ],
});
