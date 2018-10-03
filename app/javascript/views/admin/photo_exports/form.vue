<template lang="pug">
  form#new_photo_export(method="POST", :url="formUrl")
    div.btn-group-left
      div.row
        div.col-sm-4
          div(class="form-group clearfix select required photo_export_filters_business_id")
            multiselect#business_id(v-model="business.selected",
              :options="business.options",
              :searchable=false,
              open-direction="bottom",
              label="label",
              track-by="value",
              placeholder="Выберите бизнес")

        div.col-sm-4
          div(class="form-group clearfix select required photo_export_filters_date_from")
            date-picker#date_from(v-model="dateFrom", :config="dateFromConfig", placeholder='Начало периода')
        div.col-sm-4
          div(class="form-group clearfix select required photo_export_filters_date_till")
            date-picker#date_till(v-model="dateTill", :config="dateTillConfig", placeholder="Конец периода")


      div.row
        div.col-sm-6
          div(class="form-group clearfix string required photo_export_filters_limit")
            input#limit(v-model="limit", placeholder="Кол-во", class="form-control string")

        div.col-sm-6
          div(class="form-group clearfix select required photo_export_filters_chief_id")
            multiselect#chief_id(v-model="chief.selected",
              :options="chief.options",
              :disabled="chief.isDisabled",
              :internal-search="false",
              @search-change="getChiefs",
              label="label",
              track-by="value",
              open-direction="bottom",
              placeholder="Выберите пользователя"
            )
              span(slot="noResult").
                К сожалению ничего не найдено

      div.row
        div.col-sm-6
          div(class="form-group clearfix select required photo_export_filters_company_ids")
            multiselect#company_ids(v-model="company.selected",
              label="label",
              track-by="value",
              open-direction="bottom",
              placeholder="Выберите компании",
              :multiple="true",
              :hide-selected="true",
              :disabled="company.isDisabled",
              :options="company.options",
              :internal-search="false",
              :clear-on-select="false",
              :close-on-select="false",
              :loading="company.isLoading",
              @search-change="getCompanies"
            )
              template(slot="clear", slot-scope="props")
                div.multiselect__clear(v-if="company.selected.length")
              span(slot="noResult").
                К сожалению ничего не найдено

        div.col-sm-6
          div(class="form-group clearfix select required photo_export_filters_signboard_ids")
            multiselect#signboard_ids(v-model="signboard.selected",
              label="label",
              track-by="value",
              open-direction="bottom",
              placeholder="Выберите вывески",
              :multiple="true",
              :hide-selected="true",
              :disabled="signboard.isDisabled",
              :options="signboard.options",
              :internal-search="false",
              :clear-on-select="false",
              :close-on-select="false",
              @search-change="getSignboards",
            )
              span(slot="noResult").
                К сожалению ничего не найдено

      div.row
        div.col-sm-12
          div(class="form-group clearfix select required photo_export_filters_checkin_type_ids")
            multiselect#checkin_type_ids(v-model="checkin_type.selected",
              label="label",
              track-by="value",
              open-direction="bottom",
              placeholder="Выберите анкеты",
              :multiple="true",
              :hide-selected="true",
              :disabled="checkin_type.isDisabled",
              :options="checkin_type.options",
              :internal-search="false",
              :clear-on-select="false",
              :close-on-select="false",
              @search-change="getCheckinTypes",
            )
              span(slot="noResult").
                К сожалению ничего не найдено

      div.row
        div.col-sm-4
          div(class="form-group clearfix select required photo_export_process_at")
            date-picker#process_at(v-model="processAt", :config="processAtConfig", placeholder="Время обработки")

        div.col-sm-6
          button.btn.btn-success#start_photo_export(v-on:click.prevent="sendForm", :class="sendDisabledClass") Сформировать выгрузку
          button.btn.btn-success#clear_form(v-on:click.prevent="clearForm") Очистить форму
      div.row
        div.col-sm-6
          span Приблизительное кол-во фото:&nbsp
          img(v-if="loading", :src="Spinner")
          span(v-else) {{ limit ? limit + ' из ' : '' }} {{ photoCount }}
</template>
<style>
  #new_photo_export .multiselect__input {
    padding: unset;
    border: unset;
  }
</style>

<script>
  import _ from 'lodash'
  import $ from 'jquery' //TODO: get rid of jQuery
  import debounce from 'debounce-promise'
  import moment from 'moment'
  import Multiselect from "vue-multiselect"
  import 'vue-multiselect/dist/vue-multiselect.min.css'
  import DatePicker from "vue-bootstrap-datetimepicker"
  import 'eonasdan-bootstrap-datetimepicker/build/css/bootstrap-datetimepicker.css'
  import Spinner from 'images/spinner'

  const DEBOUNCE = 1500;
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
    components: { DatePicker, Multiselect, Spinner, moment, debounce },
    data() {
      return {
        Spinner,
        formUrl: '/web_api/admin/photo_exports.json',
        loading: false,
        business: {
          url: '/web_api/businesses.json',
          selected: null,
          options: []
        },
        chief: {
          url: '/web_api/users.json',
          selected: null,
          options: [],
          isLoading: false,
          isDisabled: true
        },
        checkin_type: {
          url: '/web_api/admin/photo_exports/checkin_types.json',
          selected: [],
          options: [],
          isLoading: false,
          isDisabled: true
        },
        company: {
          url: '/web_api/admin/photo_exports/companies.json',
          selected: [],
          options: [],
          isLoading: false,
          isDisabled: true
        },
        signboard: {
          url: '/web_api/admin/photo_exports/signboards.json',
          selected: [],
          options: [],
          isLoading: false,
          isDisabled: true
        },
        dateFrom: null,
        dateTill: null,
        limit: null,
        processAt: null,
        photoCount: 'N/A',
        dateFromConfig: {
          ...DefaultDatePickerConfig,
          format: 'DD.MM.YYYY',
          minDate: moment().subtract(4, 'months'),
          maxDate: moment().day(7),
          useCurrent: false
        },
        dateTillConfig: {
          ...DefaultDatePickerConfig,
          format: 'DD.MM.YYYY',
          minDate: moment().subtract(4, 'months'),
          maxDate: moment().day(7),
          useCurrent: false
        },
        processAtConfig: {
          ...DefaultDatePickerConfig,
          minDate: moment(),
          maxDate: moment().day(7),
          useCurrent: true
        },
        requiredFieldChanged: null,
        createdRecord: null,
        sendDisabledClass: 'disabled'
      }
    },

    mounted() {
      $.ajaxSetup({
        headers: {
          'X-Csrf-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      });
      this.getBusinesses()
    },

    methods: {
      post: function (url, data, callback) {
        return $.ajax({
          url: url,
          dataType: 'json',
          type: 'POST',
          data: data,
          cache: false,
          success: function (data, params) {
            callback(data);
          },
          error: function (data, text, error) {
            if (data.status === 0) {
              return data.status = '0';
            }
          }
        });
      },

      getBusinesses: function() {
        let self = this.business;
        return $.getJSON(self.url,
          { fields: ['id', 'name'] },
          (result) => {
            self.options = result.map((arg) => { return { label: arg.name, value: arg.id } });
          })
      },

      getChiefs: debounce(function(search) {
        let self = this.chief;
        self.options = [];

        let req = this.__composeRequest(self, search,
          { business_id: this.businessId,
            fields: ['id', 'name'],
            search: search
          });

        return this.__returnResponse(self, req, search)
      }, DEBOUNCE),

      getCompanies: debounce(function(search) {
        let self = this.company;
        self.options = [];

        let req = this.__composeRequest(self, search,
          { business_id: this.businessId,
            chief_id: this.chiefId,
            date_from: this.dateFromToStr,
            date_till:  this.dateTillToStr,
            search: search
          });

        return this.__returnResponse(self, req, search)
      }, DEBOUNCE),

      getSignboards: debounce(function(search) {
        let self = this.signboard;
        self.options = [];

        let req = this.__composeRequest(self, search,
          { business_id: this.businessId,
            chief_id: this.chiefId,
            company_ids: this.companyIds,
            date_from: this.dateFromToStr,
            date_till:  this.dateTillToStr,
            search: search
          });

        return this.__returnResponse(self, req, search)
      }, DEBOUNCE),

      getCheckinTypes: debounce(function(search) {
        let self = this.checkin_type;
        self.options = [];

        let req = this.__composeRequest(self, search,
          { business_id: this.businessId,
            chief_id: this.chiefId,
            company_ids: this.companyIds,
            signboard_ids: this.signboardIds,
            date_from: this.dateFromToStr,
            date_till:  this.dateTillToStr,
            search: search
          });

        return this.__returnResponse(self, req, search)

      }, DEBOUNCE),

      getPhotoCount: function() {

        return $.getJSON('/web_api/admin/photo_exports/average_photo_count.json',
          { business_id: this.businessId,
            chief_id: this.chiefId,
            company_ids: this.companyIds,
            signboard_ids: this.signboardIds,
            checkin_type_ids: this.checkinTypeIds,
            date_from: this.dateFromToStr,
            date_till:  this.dateTillToStr,
             },
          function (result) {
            this.photoCount = result.photo_count;
            this.loading = false;
          }.bind(this))
      },
      areRequiredFieldsFilled() {
        return _.filter([ this.businessId, this.dateFrom, this.dateTill ], _.isNil).length === 0
      },

      sendForm () {
        let data = {
          filters: {
            limit: this.limit,
            business_id: this.businessId,
            chief_id: this.chiefId,
            company_ids: this.companyIds,
            signboard_ids: this.signboardIds,
            checkin_type_ids: this.checkinTypeIds,
            date_from: this.dateFromToStr,
            date_till: this.dateTillToStr
          },
          process_at: this.processAtToStr
        };

        this.post(this.formUrl,
                  data,
                  function(result){ this.$emit('export-received', result) }.bind(this));
      },
      clearOptionalFields () {
        [this.chief, this.company, this.signboard, this.checkin_type].forEach((i) => {
          i.options = [];
          i.selected = i === this.chief ? null : []
        })
      },
      clearForm() {
        this.clearOptionalFields();
        this.business.selected = null;
        this.dateFrom = null;
        this.dateTill = null
      },
      __returnResponse(self, req, search){
        if(search){
          self.isLoading = true;
        }
        else{
          self.isDisabled = true;
        }
        return req()
      },
      __composeRequest(self, search, data){
        return () => {
          return $.getJSON(self.url, data).then((result) => {
            search ? self.isLoading = false : self.isDisabled = false;
            self.options = _.map(result, (arg) => { return { label: arg.name, value: (arg.ids || arg.id) } })
          })
        }
      }
    },

    computed: {
      requiredFields() {
        this.businessId
        this.dateFrom
        this.dateTill
        return Date.now()
      },
      allFields(){
        return [this.companyIds,
        this.chiefId,
        this.signboardIds,
        this.checkinTypeIds,
        this.requiredFieldChanged].join('')
      },
      businessId(){
        return (this.business.selected || {}).value
      },
      chiefId(){
        return (this.chief.selected || {}).value
      },
      companyIds(){
        return _.flatMap(this.company.selected, 'value')
      },
      signboardIds(){
        return _.flatMap(this.signboard.selected, 'value')
      },
      checkinTypeIds(){
        return _.flatMap(this.checkin_type.selected, 'value')
      },
      dateFromToStr(){
        if (this.dateFrom){ return this.dateFrom.format("YYYY-MM-DD") }
      },
      dateTillToStr(){
        if(this.dateTill){ return this.dateTill.format("YYYY-MM-DD") }
      },
      processAtToStr(){
        if(this.processAt){ return this.processAt.toISOString() }
      }
    },

    watch: {
      'business.selected': function () {
        this.clearOptionalFields();
      },
      requiredFields(){
        if(this.areRequiredFieldsFilled()) {
          this.requiredFieldChanged = Date.now()
          this.sendDisabledClass = null
        }
        else { this.sendDisabledClass = 'disabled' }
      },
      allFields: async function(val) {
        if(this.areRequiredFieldsFilled()) {
          this.loading = true;
          this.getChiefs();
          await Promise.all([
            this.getCompanies(),
            this.getSignboards(),
            this.getCheckinTypes()
          ]);
          return this.getPhotoCount()
        }
      }
    }
  }
</script>

