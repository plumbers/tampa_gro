import Vue from 'vue';

export default {
  namespaced: true,

  state(){
    return {
      dateFrom: null,
      dateTill: null,
    }
  },

  actions: {
    
    updateDateRange: function({ dispatch, commit }, payload){
      console.log('updateDateRange', payload)
      let opts = {
        date_from: payload.date_from.toString("yyyy-MM-dd"),
        date_till: payload.date_till.toString("yyyy-MM-dd")
      }
      commit('set_date_range', opts)
    },
 
  },
  
  mutations: {

    ['set_date_range'] (state, options) {
      console.log('set_date_range', state, options)
      Vue.set(state, 'dateFrom', options.date_from)
      Vue.set(state, 'dateTill', options.date_till)
    },

  },

  getters: {

    items: state => state,

  },

}
