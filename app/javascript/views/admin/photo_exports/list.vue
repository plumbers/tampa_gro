<template lang="pug">
  .table-responsive
    table#table.table-striped
      thead
        tr
          th
            span Время
            br
            span.label.label-default Создано
            span.label.label-info Начало
            span.label.label-success Конец
          th Статус
          th Кол-во фото/ошибок
          th(v-show="canDownload") Скачать
          th Сведения
      tbody
        tr(v-for="item in items")
          td
            span.label.label-default(v-show="item.created_at") {{ moment(item.created_at).format('LT DD.MM.YY') }}
            br
            span.label.label-info(v-show="item.started_at") {{ moment(item.started_at).format('LT DD.MM.YY') }}
            br
            span.label.label-success(v-show="item.ended_at") {{ moment(item.ended_at).format('LT DD.MM.YY') }}
          td
           .progress_status
             progress-bar(v-bind:state="item.status", :percent="item.percent", :innerText="item.inner_text", :finishedText="finishedText(item)")
          td {{ item.photos_count }} {{ item.errors_count ? '/ ' + item.errors_count : '' }}
          td
            a(v-bind:href="itemPath(item)") Подробнее
    infinite-loading(:on-infinite="getItems", spinner="waveDots")
      span(slot="no-results").
        Ничего не найдено :(
      span(slot="no-more").
        Больше ничего нет :)
</template>

<style scoped>
  .loading{
    flex: 1
  }
</style>

<script>
  import ProgressBar from '../../shared/progress_bar/ProgressBar.vue'
  import InfiniteLoading from 'vue-infinite-loading';

  export default {
    name: 'photo-exports-list',
    props: ['newExport'],
    components: { ProgressBar, InfiniteLoading },
    data() {
      return {
        canDownload: false,
        items: [],
        columns: ['created_at', 'status'],
        page: 1
      }
    },
    mounted(){
      setInterval(this.statusableIds, 100000)
    },
    methods: {
      getItems: _.debounce(function($state){
        return $.getJSON(`/web_api/admin/photo_exports.json?page=${this.page}`).then((result) => {
          if(result.length > 0) {
            this.items = this.items.concat(result);
            this.page = this.page + 1;
            $state.loaded()
          }
          else{
            $state.complete()
          }
        });
      }, 1000),
      moment(time){
        return window.moment(time)
      },
      itemPath(item){
        return '/admin/photo_exports/' + item.id
      },
      updateItems(result){
        this.items = _.unionBy(result, this.items, 'id')
      },
      statusableIds(){
        let ids = _.map(_.filter(this.items, (item)=>{ return item.status === 'not_started' || item.status === 'in_progress' }), 'id');
        if(ids.length > 0){
          this.getProgress(ids)
        }
      },
      getProgress(ids){
        $.getJSON('/progress_status.json', { model: 'PhotoExport', statusable_ids: ids}).
        then((result) => {
          result.forEach((newItem) => {
            let item = _.find(this.items, {id: newItem.id});
            _.extend(item, newItem)
          })
        });
      },
      finishedText(item){
        return `<a href='${item.download}'>${item.inner_text}</a>`
      }

    },
    watch: {
      newExport(){
        this.items.unshift(this.newExport);
        if(this.items.length > 25){ this.items.pop }
      }
    }
  }
</script>
