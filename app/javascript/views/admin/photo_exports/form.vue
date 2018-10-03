<template lang="pug">

  form#new_photo_export(method="POST")
    div.btn-group-left
      div.row
        div.col-sm-4
          div(class="form-group clearfix select required photo_export_filters_date_from")
            v-date-picker(
              v-model='selectedDate',
              :input-props='{ class: "input", placeholder: "Период выгрузки", readonly: true }',
              mode='range',
              :formats='{ highlight: { backgroundColor: \'#ff8080\' } }',
              show-caps,
              :is-required="true",
              @input='updateDateRange(selectedDate, { formatInput: true, hidePopover: false })',
            )
            // :theme-styles='themeStyles',
            // :formats='DateRangeFormats',
            // :attributes='DateRangeAttrs',
        div.col-sm-4
          businesses-select(
            field = 'business',
            placeholder = "Выберите бизнес",
            :multiple = "false",
            :close_on_select = "true",
            :childComps="['chief','company','signboard','location_type','location_external','checkin_type','question']",
          )
        div.col-sm-4
          chiefs-select(
            field = 'chief',
            placeholder = "Выберите пользователя",
            :multiple = "false",
            :close_on_select = "true",
            :childComps="['company','signboard','location_type','location_external', 'checkin_type','question']",
          )

      div.row.col-sm-12.form-group
        label.control-label(class="form-group") Атрибуты TT

        div.row
          div.col-sm-6
            companies-select(
              field = 'company',
              placeholder = "Выберите компании",
              :childComps="['signboard', 'location_type', 'location_external',  'checkin_type','question']",
            )
          div.col-sm-6
            signboards-select(
              field = 'signboard',
              placeholder = "Выберите вывески",
              :childComps="['company', 'location_type', 'location_external',  'checkin_type','question']",
            )

        div.row
          div.col-sm-6
            location-types-select(
              field = 'location_type',
              placeholder = "Выберите типы ТТ",
              :childComps="['company','signboard', 'location_external', 'checkin_type','question']",
            )
          div.col-sm-6
            location-ext-select(
              field = 'location_external',
              placeholder = "Выберите внешние ID ТТ",
              :childComps="['company','signboard', 'location_type', 'checkin_type','question']",
            )

      div.row
        div.col-sm-12
          checkin-types-select(
            field = 'checkin_type',
            placeholder = "Выберите анкеты",
            :childComps="['question']",
          )

      div.row
        div.col-sm-12
          questions-select(
            field = 'question',
            placeholder = "Выберите вопросы анкет",
            :childComps="[]",
          )

      div.row
        div.col-sm-12
          multiselect(
            v-model="subfolders.selected",
            :options="subfolders.options",
            placeholder = "Выберите подкаталоги архива",
            :multiple="true",
            :taggable="true",
            :allow-empty="true",
            :close-on-select="false",
            :hide-selected="true",
            open-direction="bottom",
            :custom-label="nameWithoutId",
            label="label",
            track-by="label",
            :preselect-first="false",
            selectLabel="Выбрать",
          )

      div.row.col-sm-12.form-group
        label.control-label(class="form-group") Атрибуты TT extra

        div.row
          div.col-sm-6(v-for="(filter, index) in extended_filters.filters", v-bind:key="index")
            extrafilter-select(
              :field = 'filter.field',
              :placeholder="filter.label",
              :childComps="[]",
          )

      div.row
        div.col-sm-4
          div(class="form-group clearfix select required photo_export_process_at")
            datetime-picker#process_at(v-model="processAt", :config="processAtConfig", placeholder="Время обработки")

        div.col-sm-6
          button.btn.btn-success#start_photo_export(
            v-on:dblclick.native=";",
            v-on:click.prevent="sendForm",
            :class="sendDisabledClass"
          ) Сформировать выгрузку
          button.btn.btn-success#clear_form(v-on:click.prevent="clearForm") Очистить форму

      div.row
        div.col-sm-6
          span Приблизительное кол-во фото:&nbsp
          img(v-if="form.getLoading", :src="Spinner")
          span(v-else) {{ form.count }}

</template>

<script>
  import Vue from 'vue';
  import moment from 'moment'
  import Spinner from 'images/spinner'

  import DatePicker from "vue-bootstrap-datetimepicker"
  import 'eonasdan-bootstrap-datetimepicker/build/css/bootstrap-datetimepicker.css'
  import VCalendar from 'v-calendar';
  import 'v-calendar/lib/v-calendar.min.css';

  import MultiSelectFilter from '@components/MultiSelectFilter'
  import Multiselect from "vue-multiselect"
  import 'vue-multiselect/dist/vue-multiselect.min.css'
  import store from '@src/vuex/store'
  import { mapState, mapGetters, mapActions } from 'vuex';
  import { required, minLength, between } from 'vuelidate/lib/validators'

  // import VueI18n from 'vue-i18n'
  // https://medium.com/@kazu_pon/performance-optimization-of-vue-i18n-83099eb45c2d
  // # _controller.rb
  // @translations = I18n.t(".")
  // form.html.haml
  // <script type="text/javascript">
  // window.I18n = = @translations.to_json.html_safe
  // Vue.use(VueI18n);
  //
  // const i18n = new VueI18n({
  //   locale: 'ru',
  //   fallbackLocale: 'ru',
  //   messages: translations
  // })

  Vue.use(VCalendar, {
    firstDayOfWeek: 2,  // Monday
    locale: 'ru'
  });

  const DefaultDatePickerConfig = {
    icons: {
      time: 'icon-time',
      date: 'icon-calendar',
      up: 'icon-chevron-up',
      down: 'icon-chevron-down',
      previous: 'icon-angle-left',
      next: 'icon-angle-right',
      today: 'icon-circle',
      clear: 'icon-trash',
      close: 'icon-off'
    },
    locale: 'ru'
  };

  export default {
    name: 'photo-exports-form',
    components: {
      'businesses-select': MultiSelectFilter,
      'chiefs-select': MultiSelectFilter,
      'companies-select': MultiSelectFilter,
      'signboards-select': MultiSelectFilter,
      'location-types-select': MultiSelectFilter,
      'location-ext-select': MultiSelectFilter,
      'checkin-types-select': MultiSelectFilter,
      'questions-select': MultiSelectFilter,
      'extrafilter-select': MultiSelectFilter,
      // 'subfolders-select': Multiselect,
      Multiselect,
      'datetime-picker': DatePicker,
      Spinner, moment,
    },
    store: store,
    data() {
      return {
        Spinner,
        subfolders: {
          options: [
            { value: 'company_name', label: 'Компания' },
            { value: 'location_type_name', label: 'Тип ТТ' },
            { value: 'signboard_name', label: 'Вывеска' },
          ],
          selected: null,
        },
        extended_filters: {
          filters: [
            { field: 'client_category', label: 'Категория клиента(client_category)' },
            { field: 'region', label: 'Регион(region)' },
            { field: 'channel', label: 'Канал(channel)' },
            { field: 'iformat', label: 'Формат(iformat)' },
            { field: 'territory', label: 'Территория(territory)' },
            { field: 'territory_type', label: 'Тип территории(territory_type)' },
            { field: 'network_name', label: 'Сеть(network_name)' },
          ],
          selected: null,
        },
        selectedDate: {
          // start: new Date(2018, 4, 1),
          // end: new Date(2018, 4, 5),
          'min-date': moment().subtract(4, 'months'),
          'max-date': moment().day(7),
          // start: moment().day(-1),
          // end: moment().day(0),
        },
        themeStyles: {
          wrapper: {
            background: 'linear-gradient(to bottom right, #fafafa, #cccccc)',
            color: '#000000',
            border: '0',
            boxShadow: '0 4px 8px 0 rgba(0, 0, 0, 0.14), 0 6px 20px 0 rgba(0, 0, 0, 0.13)',
            borderRadius: '5px',
          },
        },
        processAt: null,
        processAtConfig: {
          ...DefaultDatePickerConfig,
          minDate: moment(),
          maxDate: moment().day(7),
          useCurrent: true
        },
        // sendDisabledClass: 'disabled',
        sendDisabledClass: null,
      }
    },
    computed: {
      ...mapState({

        form (state, getters) {
          return getters['photo_count/form']
        },

      }),
    },
    created() {
      store.dispatch("initModules", null);
    },

    mounted() {
      this.$store.dispatch("business/getItems", null)
    },

    methods: {

      ...mapActions({
        updateDateRangeValues (dispatch, payload) {
          return dispatch('date_range/updateDateRange', payload)
        }
        // getFilterdunter (dispatch, payload) {
        //   return dispatch('date_range/updateDateRange', payload)
        // },
      }),

      updateDateRange: function(value) {
        this.updateDateRangeValues({ date_from: value.start, date_till: value.end })
      },

      // areRequiredFieldsFilled() {
      //   return _.filter([ this.businessId, this.dateFrom, this.dateTill ], _.isNil).length === 0
      // },

      sendForm () {
        this.$store.dispatch('photo_export/submitForm', this.$store)
      },

      clearForm() {
        this.$store.dispatch('photo_export/clearForm', this.$store);
      },

      nameWithoutId ({ label }) {
        return label
      },

      // addTag (newTag) {
      //   let tag = {
      //     name: newTag,
      //     code: newTag.substring(0, 2) + Math.floor((Math.random() * 10000000))
      //   }
      //   this.location_groups_list.options.push(tag)
      //   this.location_groups_list.value.push(tag)
      //   this.selected_values = this.location_groups_list.value.join(',')
      //   this.postGroup(newTag)
      // },

    },

  }
</script>

<style>
  #new_photo_export .multiselect__input {
    padding: unset;
    border: unset;
  }
  li.multiselect__element {
    padding: 0 0 0 0;
  }
</style>
