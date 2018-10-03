<template lang="pug">

  div(class='form-group clearfix select required')
    multiselect(
      :options="items.options",
      :allow-empty="allow_empty",
      :disabled="items.getDisabled",
      :internal-search="internal_search",
      :searchable="searchable",
      :close-on-select="close_on_select",
      open-direction="bottom",
      label="label",
      track-by="value",
      :placeholder="placeholder",
      :multiple="multiple",

      :taggable="true",
      :clear-on-select="clear_on_select",
      :hide-selected="true",
      :preserve-search="true",

      :custom-label="labelWithoutValue",
      deselectLabel="",
      selectedLabel="",
      :preselect-first="false",
      tag-placeholder="",
      selectLabel="",
      :loading="items.getLoading",
      @close="onCloseOptions",
      @input="onInputOption",
      @select="onSelectOption",
      @search-change="onSearchChange",
    )
      span(slot="noResult").
        К сожалению ничего не найдено

</template>

<script>

import debounce from 'debounce-promise'
import { mapState, mapGetters, mapActions } from 'vuex';
import store from '@src/vuex/store'
import Multiselect from "vue-multiselect"
import 'vue-multiselect/dist/vue-multiselect.min.css'

const DEBOUNCE = 4000;

export default {

  store: store,

  props: {
    field: {
      type: String
    },
    allow_empty: {
      type: Boolean,
      default: true
    },
    internal_search: {
      type: Boolean,
      default: true,
    },
    searchable: {
      type: Boolean,
      default: true,
    },
    close_on_select: {
      type: Boolean,
      default: false,
    },
    placeholder: {
      type: String
    },
    multiple: {
      type: Boolean,
      default: true,
    },
    childComps: {
      type: Array,
      default: () => []
    },
    clear_on_select: {
      type: Boolean,
      default: false,
    },
    reset_after: {
      type: Boolean,
      default: true,
    },
  },

  components: {
    'multiselect': Multiselect,
    debounce,
  },

  computed: {
    ...mapState({

      state (state) {
        return state[this.field]
      },
      items (state, getters) {
        return getters[this.field + '/items']
      },

    }),

  },

  methods: {

    ...mapActions({

      getItems (dispatch, payload) {
        return dispatch(this.field + '/getItems', payload)
      },
      updateSelectedValue (dispatch, payload) {
        return dispatch(this.field + '/updateSelectedValueAction', payload)
      },
      updateSearchQuery (dispatch, search) {
        return dispatch(this.field + '/updateSearchQueryAction', search)
      },

    }),

    labelWithoutValue ({ label, value }) {
      return label
    },

    mapName(value){
      return _.map(value, (arg) => { return arg.name })
    },

    onCloseOptions(selectedOption, value) {
      debounce(function(value){
        this.$emit('on_'+this.field+'_closed', selectedOption)
      }, DEBOUNCE)
    },

    onInputOption: debounce(function(selectedOption, value){
        this.$emit('on_'+this.field+'_changed', selectedOption)
        //ToDo: move dependent's comp logic from below to vuex module
        // this.updateSelectedValue({selected: selectedOption, children: this.childComps})
        this.updateSelectedValue(selectedOption)
        this.childComps.forEach((child) => {
          setTimeout(() => {
            this.$store.dispatch(child + '/getItems', value, selectedOption )
          }, (Math.floor(Math.random() * 5 + 1))*100
          )
        })
      }, DEBOUNCE
    ),

    onSelectOption(selectedOption, value) {
      debounce(function(value){
        this.$emit('on_'+this.field+'_selected', selectedOption)
      }, DEBOUNCE)
    },

    onSearchChange: debounce(function(search_query){
        this.updateSearchQuery(search_query)
      }, DEBOUNCE
    ),
        
  },
}

</script>
  
<style scoped>
  li.multiselect__element {
    padding: 0 0 0 0;
  }
  .multiselect__tags {
    min-height: 40px;
    display: block;
    padding: 0px 40px 0 0px;
  }
</style>
