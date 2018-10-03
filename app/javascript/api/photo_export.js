import Vue from 'vue'
import VueAxios from 'vue-axios'

import api from '@api/axios'
Vue.use(VueAxios, api)

//ToDo: request cancelation - var CancelToken = axios.CancelToken;

import { cacheAdapterEnhancer, throttleAdapterEnhancer } from 'axios-extensions';

const submitForm = function(store, params, { uri, mutationTypes, stateKey }) {

  console.log('submitForm', params);
  store.commit('photo_export/'+mutationTypes.PENDING);

  return new Promise((resolve) => {
    setTimeout(() => {      
      resolve(
        api.post(uri, params).then(response => {
            const result = JSON.stringify(response)
            console.log('api.post', uri, result);
            store.commit(mutationTypes.SUCCESS, result);
        }).catch(error => {
          store.commit( mutationTypes.FAILURE, { error: error } )
        }).finally(response => {
          store.commit( mutationTypes.FINALLY, { final: 'countdown:' + JSON.stringify(response) } );
        })
      ); //resolve
    }, 1000);
  }
  ); //new Promise
}

const getItemsCount = function(store, params, { uri, mutationTypes, stateKey }) {
  store.commit(mutationTypes.PENDING);
  return new Promise((resolve) => {
    setTimeout(() => {
      let throttle_axios = throttleAdapterEnhancer(api.defaults.adapter, { threshold: 3 * 1000 });
      let options = {
        params:  params,
        adapter: throttle_axios,
      };
      resolve(
        api.get(uri, options).then(response => {
          store.commit(mutationTypes.SUCCESS, response.data);
        }
        ).catch(error => {
          store.commit( mutationTypes.FAILURE, { error: error } )
        }
        ).finally(response => {
          store.commit( mutationTypes.FINALLY )
        }
        )
      ); //resolve
  
    }, 1000);
  }); //new Promise
}

export {
  submitForm,
  getItemsCount,
};
