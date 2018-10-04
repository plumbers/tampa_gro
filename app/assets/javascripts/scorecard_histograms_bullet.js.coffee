do ->
# Chart design based on the recommendations of Stephen Few. Implementation
# based on the work of Clint Ivy, Jamie Love, and Jason Davies.
# http://projects.instantcognition.com/protovis/bulletchart/

  bulletRanges = (d) ->
    d.ranges

  bulletMarkers = (d) ->
    d.markers

  bulletMeasures = (d) ->
    d.measures

  bulletTranslate = (x) ->
    (d) ->
      'translate(' + x(d) + ',0)'

  bulletWidth = (x) ->
    x0 = x(0)
    (d) ->
      Math.abs x(d) - x0

  d3.bullet = ->
    orient = 'left'
    reverse = false
    duration = 0
    ranges = bulletRanges
    markers = bulletMarkers
    measures = bulletMeasures
    width = 480
    height = 30
    tickFormat = null
    # left, right, top, bottom
    # For each small multiple…

    bullet = (g) ->
      g.each (d, i) ->
        `var g`
        rangez = ranges.call(this, d, i).slice()#.sort(d3.descending)
        markerz = markers.call(this, d, i).slice()#.sort(d3.descending)
        measurez = measures.call(this, d, i).slice()#.sort(d3.descending)
        g = d3.select(this)
        # Compute the new x-scale.
        x1 = d3.scale.linear().domain([
          0
          Math.max(rangez[0], markerz[0], measurez[0])
        ]).range(if reverse then [
          width
          0
        ] else [
          0
          width
        ])
        # Retrieve the old x-scale, if this is an update.
        x0 = @__chart__ or d3.scale.linear().domain([
          0
          Infinity
        ]).range(x1.range())
        # Stash the new scale.
        @__chart__ = x1
        # Derive width-scales from the x-scales.
        w0 = bulletWidth(x0)
        w1 = bulletWidth(x1)

        # Update the range rects.
        range = g.selectAll('rect.range').data(rangez)
        range.enter().append('rect').attr('class', (d, i) ->
          'range s' + i
        ).attr('width', w0).attr('height', height).attr('x', if reverse then x0 else 0).transition().duration(duration).attr('width', w1).attr 'x', if reverse then x1 else 0
        range.transition().duration(duration).attr('x', if reverse then x1 else 0).attr('width', w1).attr 'height', height/2

        # Update the measure rects.
        measure = g.selectAll('rect.measure').data(measurez)

        measure.enter().append('rect').attr('class', (d, i) ->
          'measure s' + i
        ).attr('width', w0).attr('height', height / 2).attr('x', if reverse then x0 else 0).attr('y', (height / 2)).transition().duration(duration).attr('width', w1).attr 'x', if reverse then x1 else 0

#        measure.transition().duration(duration).attr('class', (d, i) ->
#          'measure s' + i
#        ).attr('width', w0).attr('height', height / 4).attr('x', if reverse then x0 else 0).attr('y', (height / 4)+i*10).transition().duration(duration).attr('width', w1).attr 'x', if reverse then x1 else 0
        measure.transition().duration(duration).attr('width', w1).attr('height', height / 2).attr('x', if reverse then x1 else 0).attr 'y', height / 2

        # Update the marker lines.
        marker = g.selectAll('line.marker').data(markerz)
        marker.enter().append('line').attr('class', 'marker').attr('x1', x0).attr('x2', x0).attr('y1', height / 6).attr('y2', height * 5 / 6).transition().duration(duration).attr('x1', x1).attr 'x2', x1
        marker.transition().duration(duration).attr('x1', x1).attr('x2', x1).attr('y1', height / 6).attr 'y2', height * 5 / 6
        # Compute the tick format.
        format = tickFormat or x1.tickFormat(8)
        # Update the tick groups.
        tick = g.selectAll('g.tick').data(x1.ticks(8), (d) ->
          @textContent or format(d)
        )
        # Initialize the ticks with the old scale, x0.
        tickEnter = tick.enter().append('g').attr('class', 'tick').attr('transform', bulletTranslate(x0)).style('opacity', 1e-6)
        tickEnter.append('line').attr('y1', height).attr 'y2', height * 7 / 6
        tickEnter.append('text').attr('text-anchor', 'middle').attr('dy', '1em').attr('y', height * 7 / 6).text format
        # Transition the entering ticks to the new scale, x1.
        tickEnter.transition().duration(duration).attr('transform', bulletTranslate(x1)).style 'opacity', 1
        # Transition the updating ticks to the new scale, x1.
        tickUpdate = tick.transition().duration(duration).attr('transform', bulletTranslate(x1)).style('opacity', 1)
        tickUpdate.select('line').attr('y1', height).attr 'y2', height * 7 / 6
        tickUpdate.select('text').attr 'y', height * 7 / 6
        # Transition the exiting ticks to the new scale, x1.
        tick.exit().transition().duration(duration).attr('transform', bulletTranslate(x1)).style('opacity', 1e-6).remove()
        return
      d3.timer.flush()
      return

    bullet.orient = (x) ->
      if !arguments.length
        return orient
      orient = x
      reverse = orient == 'right' or orient == 'bottom'
      bullet

    # ranges (bad, satisfactory, good)

    bullet.ranges = (x) ->
      if !arguments.length
        return ranges
      ranges = x
      bullet

    # markers (previous, goal)

    bullet.markers = (x) ->
      if !arguments.length
        return markers
      markers = x
      bullet

    # measures (actual, forecast)

    bullet.measures = (x) ->
      if !arguments.length
        return measures
      measures = x
      bullet

    bullet.width = (x) ->
      if !arguments.length
        return width
      width = x
      bullet

    bullet.height = (x) ->
      if !arguments.length
        return height
      height = x
      bullet

    bullet.tickFormat = (x) ->
      if !arguments.length
        return tickFormat
      tickFormat = x
      bullet

    bullet.duration = (x) ->
      if !arguments.length
        return duration
      duration = x
      bullet

    bullet

  return