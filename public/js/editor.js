const cloud = qs('cloud')
const securityToken = qs('securityToken')
const user = qs('user')
const password = qs('password')

// Favor securityToken over user/password combination
const securityParams = securityToken ? '&securityToken=' + securityToken : '&user=' + user + '&password=' + password

// Handle submit on request form
$('#theForm').on('submit', function (e) {
  e.preventDefault()
  const data = $(this).serialize()
  const url = '/api/?cloud=' + cloud + securityParams
  $.post(url, data, function (response) {
    alert(response.message)
  })
  .fail(function (xhr) {
    alert(xhr.statusText)
  })
})

// DOM ready
$(document).ready(function() {
  // check if baldr has json values if date is mentioned in the queryString
  const date = qs('date')
  if (!jQuery.isEmptyObject(date)) {
    // query baldr for a specific date in query String
    const url = window.location.origin + '/api/?cloud=' + cloud + '&date=' + date + securityParams
    let msg = $.ajax({
      type: "GET",
      url: url,
      contentType: 'application/json; charset=utf-8',
      async: false
    }).responseText;
    // Update the existing json in the editor if it exists for the specified date else show the sample-input
    if (msg.indexOf('fqdn') != -1) {
      $('#snapshot').val(msg)
    } else {
      $.getJSON('sample-input.json', function(jsonValue) {
        $('#snapshot').val(JSON.stringify(jsonValue))
      })
    }
  } else {
    // show the sample input if date is not passed in the queryString
    $.getJSON('sample-input.json', function(jsonValue) {
      $('#snapshot').val(JSON.stringify(jsonValue))
    })
  }
})
