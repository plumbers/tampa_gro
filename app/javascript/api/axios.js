import axios from 'axios'

const WEB_API_URL = process.env.WEB_API_URL || 'http://localhost:3002/web_api'

export default axios.create({
  baseURL: WEB_API_URL,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
    credentials: 'same-origin',
    'Access-Control-Allow-Origin': '*',
  }
})
