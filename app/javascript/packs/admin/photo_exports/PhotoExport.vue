<template lang="pug">

  #form
    .row
      .col-sm-12
        photo-exports-form(v-on:export-received='addPhotoItem')
    .row
      .col-sm-12
        photo-exports-list#upload-status.uploads_status(v-bind:new-export='newExport')

</template>

<script>

  import PhotoExportsForm from '@views/admin/photo_exports/form';
  import PhotoExportsList from '@views/admin/photo_exports/list';

  export default {
    name: 'PhotoExport',
    data(){
      return{
        newExport: null
      }
    },
    components: {
      'photo-exports-form': PhotoExportsForm,
      'photo-exports-list': PhotoExportsList,
    },
    methods: {
      addPhotoItem(obj){
        this.newExport = obj;
      }
    }
  };

</script>

<style lang="scss" scoped>

</style>
