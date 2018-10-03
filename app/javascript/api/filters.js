import Vue from 'vue'
import VueAxios from 'vue-axios'

import api from '@api/axios'
Vue.use(VueAxios, api)

import { cacheAdapterEnhancer, throttleAdapterEnhancer } from 'axios-extensions';

const fetchCollection = function(store, params, { uri, mutationTypes, stateKey }) {
  store.commit(mutationTypes.PENDING);
  return new Promise((resolve) => {
    setTimeout(() => {
      let throttle_axios = throttleAdapterEnhancer(api.defaults.adapter, { threshold: 2 * 1000 });
      let options = {
        params:  params,
        adapter: throttle_axios,
      };
      resolve(
        api.get(uri, options).then(response => {
            let result = _.map(response.data, (arg) => { return { label: arg.name, value: (arg.ids || arg.id) } });
            result =  { options: result }
            store.commit(mutationTypes.SUCCESS, result);
          }
        ).catch(error => {
          store.commit( mutationTypes.FAILURE, { error: error } )
        }
        ).finally(response => {
          store.commit( mutationTypes.FINALLY, { final: 'countdown:' + JSON.stringify(response) } );
        }
        )
      ); //resolve

    }, 1000);
  }
  ); //new Promise
}

export {
  fetchCollection,
};
