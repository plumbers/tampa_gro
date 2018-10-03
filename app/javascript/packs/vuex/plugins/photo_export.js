const photoExportCounter = function (store) {
  store.subscribe(function (mutation, state) {

    if (mutation.type.endsWith('GET_PENDING')) {
      store.dispatch('incPending', store);
    }
    
    if (mutation.type.endsWith('GET_FINALLY')) {
      store.dispatch('decPending', store);
      if(state.inPendingStateCounter==0 && state.business.selected!=null && !mutation.type.startsWith('photo_count')){
        store.dispatch('photo_count/getPhotoCount', store);
      }
    }

  })
}

const photoExportSearchQuery = function (store) {
  store.subscribe(function (mutation, state) {
    if (mutation.type.endsWith('updateSearchQuery')) {
      store.dispatch(mutation.type.replace('updateSearchQuery', '') + 'getItems', null);
    }
  })
}

export {
  photoExportCounter,
  photoExportSearchQuery,
}
