// DOM ready
$(document).ready(function () {
  // Parse querystring
  const cloud = qs('cloud')
  const snapshotDate = qs('date')
  const securityToken = qs('securityToken')
  const user = qs('user')
  const password = qs('password')

  // Favor securityToken over user/password combination
  const securityParams = securityToken ? '&securityToken=' + securityToken : '&user=' + user + '&password=' + password

  // Load content from our API
  $.getJSON('/api/?cloud=' + cloud + '&date=' + snapshotDate + securityParams, function (reportData) {
    // Show main report (hidden in case we need to show alert due to no data)
    $('#main').collapse('show')

    // Setup chart reference
    const myChart = $('#myChart')

    // Create doughnut with our data and options
    const myDoughnutChart = new Chart(myChart, {
        type: 'doughnut',
        data: setupChartData(reportData),
        options: setupChartOptions(Chart, reportData)
    })

    // Fill in UI
    $('#fqdn').text(reportData.fqdn)
    $('#snapshotDate').text(reportData.snapshotDate)
    $('#last24h').text(reportData.last24h)
    $('#last24h').colorCode()
    $('#last7d').text(reportData.last7d).colorCode()
    $('#last14d').text(reportData.last14d).colorCode()
    let totalImpact = 0
    let tableRow = ''
    let impactText = ''

    // Create table of recommendations
    for (let index in reportData.recommendations) {
      let recommendation = reportData.recommendations[index]
      if (recommendation.impact) {
        totalImpact += parseFloat(recommendation.impact)
        impactText = '+' + recommendation.impact + '%'
      } else {
        impactText = recommendation.impactMessage
      }
      tableRow = '<tr><th scope="row">' + recommendation.rank + '</th><td>' + recommendation.recommendation + '</td><td>' + impactText + '</td></tr>'
      $('#recommendationsTable > tbody:last-child').append(tableRow)
    }

    // Round totalImpact to 2 decimal points (Genesis)
    totalImpact = totalImpact.toFixed(2)

    // Create table of problematic devices
    $('#totalImpact').text(totalImpact)
    for (let index in reportData.topProblematicDevices) {
      let problematicDevice = reportData.topProblematicDevices[index]
      tableRow = '<tr><th scope="row">' + problematicDevice.rank + '</th><td>' + problematicDevice.model + '</td><td>' + problematicDevice.os + '</td><td>' + problematicDevice.id + '</td><td>' + problematicDevice.passed + '</td><td>' + problematicDevice.failed + '</td><td>' + problematicDevice.errors + '</td></tr>'
      $('#devicesTable > tbody:last-child').append(tableRow)
    }

    // Create table of problematic tests
    for (let index in reportData.topFailingTests) {
      let test = reportData.topFailingTests[index]
      tableRow = '<tr><th scope="row">' + test.rank + '</th><td>' + test.test + '</td><td>' + test.age + 'd</td><td>' + test.failures + '</td><td>' + test.passes + '</td></tr>'
      $('#testsTable > tbody:last-child').append(tableRow)
    }
  }) // Get JSON
  .fail(function(e) { // Handle no data for cloud/date combination
    $('#noData').text(e.message)
    // Set alert message
    $('#alertCloud').text(cloud ? cloud : '<unspecified>')
    $('#alertSnapshotDate').text(snapshotDate ? snapshotDate : '<unspecified>')
    $('#noData').collapse('show') // show alert
  })
}) // DOM read
