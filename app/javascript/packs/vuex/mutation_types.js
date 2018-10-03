import _ from 'lodash'

const createAsyncMutation = (type) => ({
  SUCCESS: `${type}_SUCCESS`,
  FAILURE: `${type}_FAILURE`,
  PENDING: `${type}_PENDING`,
  FINALLY: `${type}_FINALLY`,
  CANCEL:  `${type}_CANCEL`,
  loadingKey: _.camelCase(`${type}_LOADING`),
  disabledKey: _.camelCase(`${type}_DISABLED`),
  stateKey: _.camelCase(`${type}_DATA`)
})

const GET_ASYNC  = createAsyncMutation('GET')
const POST_ASYNC = createAsyncMutation('POST')
const GET_COUNT  = createAsyncMutation('GET_COUNT')

export {
  GET_ASYNC,
  POST_ASYNC,
  GET_COUNT,
}
