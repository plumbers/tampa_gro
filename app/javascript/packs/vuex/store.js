import Vue from 'vue';
import Vuex from 'vuex';
Vue.use(Vuex)

const requireModule = require.context('./modules/', false, /.*$/)
import { photoExportCounter, photoExportSearchQuery } from './plugins/photo_export'

const MODULES = [
  { name: 'business',           uri: '/businesses.json' },
  { name: 'chief',              uri: '/users.json' },

  { name: 'company',            uri: '/admin/photo_exports/companies.json' },
  { name: 'signboard',          uri: '/admin/photo_exports/signboards.json' },
  { name: 'location_type',      uri: '/admin/photo_exports/location_types.json' },
  { name: 'location_external',  uri: '/admin/photo_exports/location_ext_ids.json' },
  { name: 'checkin_type',       uri: '/admin/photo_exports/checkin_types.json' },
  { name: 'question',           uri: '/admin/photo_exports/questions.json' },
  // extra
  { name: 'client_category',    uri: '/admin/photo_exports/client_category.json' },
  { name: 'region',             uri: '/admin/photo_exports/region.json' },
  { name: 'channel',            uri: '/admin/photo_exports/channel.json' },
  { name: 'iformat',            uri: '/admin/photo_exports/iformat.json' },
  { name: 'territory',          uri: '/admin/photo_exports/territory.json' },
  { name: 'territory_type',     uri: '/admin/photo_exports/territory_type.json' },
  { name: 'network_name',       uri: '/admin/photo_exports/network_name.json' },

  { name: 'photo_count',        uri: '/admin/photo_exports/photo_count.json', file: './photo_export.js' },
  { name: 'photo_export',       uri: '/admin/photo_exports.json',             file: './photo_export.js' },
]

function defineModule(module_name){
  return {
    namespaced: true,
    ...requireModule(module_name).default
  }
}

let modules = {}
modules['date_range']= defineModule('./date_range.js')
MODULES.forEach(module => {
  modules[module.name] = defineModule(module.file || './filters.js')
})

const store = new Vuex.Store({
  namespaced: true,
  strict: process.env.NODE_ENV !== 'production',
  state:{
    inPendingStateCounter: 0,
  },
  modules,  
  actions: {
    initModules: ({ commit, state }) => {
      MODULES.forEach(module => {
        console.log('initModules', module.name, module.uri)
        let opts = { state: state, name: module.name, uri: module.uri, root: true }
        commit(module.name + '/init_module', opts, opts)
      })      
    },
    incPending: ({ commit, state }) => {  commit('inc_pending', state) },
    decPending: ({ commit, state }) => {  commit('dec_pending', state) },
  },
  mutations: {
    ['inc_pending'] (state) { state.inPendingStateCounter+=1 },
    ['dec_pending'] (state) { state.inPendingStateCounter-=1 },
  },
  plugins: [photoExportCounter, photoExportSearchQuery],
})

export default store
