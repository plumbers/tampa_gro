import Vue from 'vue';
import Vuex from 'vuex';
import { submitForm, getItemsCount } from '@api/photo_export';
import * as types from '@src/vuex/mutation_types'
import * as util  from '@util/fields_helpers'

Vue.use(Vuex);

export default {
  namespaced: true,

  state(){
    return {
      name: null,
      uri: null,
      count: 0,
    }
  },
  
  actions: {

    submitForm: function({ commit, state }, store){
      const preparedParams = util.prepareParams(store)
      submitForm(store, preparedParams, {
        uri: state.uri,
        mutationTypes: types.POST_ASYNC
      })
    },

    clearForm: function({ commit, state }, store){
      const preparedParams = util.prepareParams(store)
    },

    getPhotoCount(store) {
      const preparedParams = util.prepareParams(store);
      getItemsCount(store, preparedParams, {
        uri: store.state.uri,
        mutationTypes: types.GET_COUNT
      })
    },
    
  },

  mutations: {

    [types.POST_ASYNC.SUCCESS] (state, result) {
      Vue.set(state, [types.POST_ASYNC.loadingKey], false)
      Vue.set(state, 'options', result.options)
    },

    [types.POST_ASYNC.FAILURE] (state, result) {
      Vue.set(state, [types.POST_ASYNC.loadingKey], false)
    },

    [types.POST_ASYNC.PENDING] (state) {
      Vue.set(state, types.POST_ASYNC.loadingKey, true)
    },

    [types.POST_ASYNC.FINALLY] (state) {
    },

    [types.GET_COUNT.SUCCESS] (state, result) {
      Vue.set(state, [types.GET_COUNT.loadingKey], false)
      Vue.set(state, 'count', result.count)
    },

    [types.GET_COUNT.FAILURE] (state, error) {
      Vue.set(state, [types.GET_COUNT.loadingKey], false)
    },

    [types.GET_COUNT.FINALLY] (state) {
      Vue.set(state, [types.GET_COUNT.loadingKey], false)
    },

    [types.GET_COUNT.PENDING] (state) {
      Vue.set(state, types.GET_COUNT.loadingKey, true)
    },
    
    ['init_module'] (payload, options) {
      Vue.set(options.state[options.name], 'name', options.name)
      Vue.set(options.state[options.name], 'uri',  options.uri)
    },
    
  },
  
  getters: {
    form: state => state,
  },

};
