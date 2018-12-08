// Extract querystring values
function qs (key) {
  key = key.replace(/[*+?^$.[\]{}()|\\/]/g, '\\$&') // escape RegEx meta chars
  let match = location.search.match(new RegExp('[?&]' + key + '=([^&]+)(&|$)'))
  return match && decodeURIComponent(match[1].replace(/\+/g, ' '))
}