import Vue from 'vue';
import { fetchCollection, getItemsCount } from '@api/filters';
import * as types from '../mutation_types'
import * as util from '@util/fields_helpers'

export default {
  namespaced: true,

  state(){
    return {
      name: '',
      uri: '',
      options: [],
      selected: null,
      getDisabled: true,
      search: '',
    }
  },

  actions: {

    getItems(store) {
      console.log(store.state.name + '.getItems', store.state.uri);
      const preparedParams = util.prepareParams(store);
      fetchCollection(store, preparedParams, {
        uri: store.state.uri,
        mutationTypes: types.GET_ASYNC        
      })
    },

    updateSelectedValueAction({ commit, state }, selected_value) {
      // const selected_value = opts.selected, dependent_components  = opts.children
      commit('updateValue', selected_value)
      //ToDo: rework here - move dependent logic from component
      // dependent_components.forEach((child) => {
      //   setTimeout(() => {
      //       commit(child + '/getItems', null, null )
      //     }, (Math.floor(Math.random() * 5 + 1))*100
      //   )
      // })
    },

    updateSearchQueryAction({ commit, state }, search_query) {
      console.log('updateSearchQueryAction', search_query)
      commit('updateSearchQuery', search_query)
    },
    
  },

  mutations: {

    [types.GET_ASYNC.SUCCESS] (state, result) {
      Vue.set(state, [types.GET_ASYNC.stateKey], state)
      Vue.set(state, [types.GET_ASYNC.loadingKey], false)
      Vue.set(state, [types.GET_ASYNC.disabledKey], false)
      Vue.set(state, 'options', result.options)
    },

    [types.GET_ASYNC.FAILURE] (state, result) {
      Vue.set(state, [types.GET_ASYNC.loadingKey], false)
      Vue.set(state, [types.GET_ASYNC.disabledKey], false)
      console.log(state.name + '.FAILURE.state', state, result.error)
    },

    [types.GET_ASYNC.PENDING] (state) {
      Vue.set(state, [types.GET_ASYNC.stateKey], state)
      Vue.set(state, types.GET_ASYNC.loadingKey, true)
      Vue.set(state, types.GET_ASYNC.disabledKey, false)
    },

    [types.GET_ASYNC.FINALLY] (state) {
      Vue.set(state, [types.GET_ASYNC.stateKey], state)
    },
    
    ['init_module'] (payload, options) {
      Vue.set(options.state[options.name], 'name', options.name)
      Vue.set(options.state[options.name], 'uri',  options.uri)
    },

    reset (state) {
      Vue.set(state, [types.GET_ASYNC.loadingKey], false)
      Vue.set(state, [types.GET_ASYNC.disabledKey], true)
      Vue.set(state, 'selected', null)
      Vue.set(state, 'options', [])
    },

    updateValue (state, selected_value) {
      state.selected = selected_value
    },

    updateSearchQuery (state, search_query) {
      state.search = search_query
    },

  },

  getters: {
    items: state => state,
  },

}
