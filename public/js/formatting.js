  // Extend jQuery to color code success rate values
jQuery.fn.extend({
  colorCode: function () {
    return this.each(function() {
      let element = $('#' + this.id)
      let value = parseInt(element.text(), 10)
      let color
      if (value > 70) {
        color = 'green'
      } else if (value > 50) {
        color = 'orange'
      } else {
        color = 'red'
      }
      element.parent().parent().parent().addClass(color)
    })
  }
})

// Setup donut style chart
Chart.pluginService.register({
  beforeDraw: function (chart) {
    if (chart.config.options.elements.center) {
      // Get ctx from string
      let ctx = chart.chart.ctx;
      
      // Get options from the center object in options
      let centerConfig = chart.config.options.elements.center;
      let fontStyle = centerConfig.fontStyle || 'Arial';
      let txt = centerConfig.text;
      let color = centerConfig.color || '#000';
      let sidePadding = centerConfig.sidePadding || 20;
      let sidePaddingCalculated = (sidePadding/100) * (chart.innerRadius * 2)
      //Start with a base font of 30px
      ctx.font = '30px ' + fontStyle;
      
      // Get the width of the string and also the width of the element minus 10 to give it 5px side padding
      let stringWidth = ctx.measureText(txt).width;
      let elementWidth = (chart.innerRadius * 2) - sidePaddingCalculated;

      // Find out how much the font can grow in width.
      let widthRatio = elementWidth / stringWidth;
      let newFontSize = Math.floor(30 * widthRatio);
      let elementHeight = (chart.innerRadius * 2);

      // Pick a new font size so it will not be larger than the height of label.
      let fontSizeToUse = Math.min(newFontSize, elementHeight);

      // Set font settings to draw it correctly.
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      let centerX = ((chart.chartArea.left + chart.chartArea.right) / 2);
      let centerY = ((chart.chartArea.top + chart.chartArea.bottom) / 2);
      ctx.font = fontSizeToUse + 'px ' + fontStyle;
      ctx.fillStyle = color;
      
      //Draw text in center
      ctx.fillText(txt, centerX, centerY);
    }
  }
});

function setupChartData(reportData) {
  return {
    labels: [
      'Lab',
      'Orchestration',
      'Scripting'
    ],
    datasets: [
      {
          data: [reportData.lab, reportData.orchestration, reportData.scripting],
          backgroundColor: [
              'rgba(153, 102, 255, 0.2)',
              'rgba(54, 162, 235, 0.2)',
              'rgba(255, 206, 86, 0.2)'
          ],
          borderColor: [
              'rgba(153, 102, 255, 1)',
              'rgba(54, 162, 235, 1)',
              'rgba(255, 206, 86, 1)'
          ],
          borderWidth: 1
      }
    ]
  };
}

function setupChartOptions(Chart, reportData) {
  return {
    devicePixelRatio: 2,
    events: false,
    legend: {
      display: true,
      position: 'right'
    },
    animation: {
      duration: 500,
      easing: 'easeOutQuart',
      onComplete: function () {
        const ctx = this.chart.ctx
        ctx.font = Chart.helpers.fontString(Chart.defaults.global.defaultFontFamily, 'normal', Chart.defaults.global.defaultFontFamily)
        ctx.textAlign = 'center'
        ctx.textBaseline = 'bottom'

        this.data.datasets.forEach(function (dataset) {
          for (let i = 0; i < dataset.data.length; i++) {
            let model = dataset._meta[Object.keys(dataset._meta)[0]].data[i]._model,
              total = dataset._meta[Object.keys(dataset._meta)[0]].total,
              mid_radius = model.innerRadius + (model.outerRadius - model.innerRadius)/2,
              start_angle = model.startAngle,
              end_angle = model.endAngle,
              mid_angle = start_angle + (end_angle - start_angle)/2

            let x = mid_radius * Math.cos(mid_angle)
            let y = mid_radius * Math.sin(mid_angle)

            ctx.fillStyle = '#000'

            let percent = String(Math.round(dataset.data[i]/total*100)) + '%'
            ctx.fillText(dataset.data[i], model.x + x, model.y + y)
            // Display percent 15 pixels below
            ctx.fillText(percent, model.x + x, model.y + y + 15)
          }
        })
      }
    },
    elements: {
      center: {
        text: 'Issues for ' + reportData.executions + ' Executions',
        color: 'darkgrey',
        fontStyle: 'Arial',
        sidePadding: 20
      }
    }
  }
}
