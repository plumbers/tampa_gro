export const getSelectedValue = function(selected_value) {
  return (selected_value && selected_value.value) ? selected_value.value : null
}

export const getFlatSelectedValues = function(selected_values) {
  return _.flatMap(selected_values, 'value')
}

const SINGLE_VALUE_FILTERS = ['business', 'chief']
const MULTI_VALUES_FILTERS = ['company', 'signboard', 'location_type', 'location_external', 'checkin_type', 'question']

export const prepareParams = function (store) {
  let params = {
    mode:        'cors',
    credentials: true,
    fields:      ['id', 'name'],
    date_from:   (store.rootState||store.state).date_range.dateFrom,
    date_till:   (store.rootState||store.state).date_range.dateTill,
    search:      store.state.search
  };
  SINGLE_VALUE_FILTERS.forEach(
    filter => { params[filter+'_id']  = getSelectedValue((store.rootState||store.state)[filter].selected) }
  )
  MULTI_VALUES_FILTERS.forEach(
    filter => { params[filter+'_ids'] = getFlatSelectedValues((store.rootState||store.state)[filter].selected) }
  )
  //ToDo: also should develop such filters:
  // # location_field_ids: :integer_array locations.data->>'client_category', etc
  return params;
};
