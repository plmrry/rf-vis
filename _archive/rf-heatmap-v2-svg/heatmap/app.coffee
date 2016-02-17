# coffeelint: disable=no_debugger
# coffeelint: disable=no_debugger

setTimeout (-> do go), 0

# window.packets = packets = []

go = ->
  dots = new Dots()

  socket = io()
  socket.on 'new packet', (arrayOfPackets) ->
    # console.log "New data size: #{arrayOfPackets.length}"
    dots.newData arrayOfPackets
    # packets = packets.concat arrayOfPackets
    # dots.updateData packets


  # setInterval (->
  #   debugger
  #   console.log packets.length
  # ), 1000

# window.onload = ->
#   # heatmap = new Heatmap()
#   #
#   # socket = io()
#   #
#   # socket.on 'new packet', (d) ->
#   #   # heatmap.add d
#   #   # console.log d

class Dots
  translate = (x, y) -> "translate(#{x},#{y})"
  packets = []
  dotSize = 2

  getNodeSize = (node) ->
    height: node.clientHeight, width: node.clientWidth

  constructor: ->
    fullSize = height: "100%", width: "100%"
    almostFull = height: "90%", width: "90%"

    d3.select("html").attr(fullSize).style(fullSize)
    d3.select("body").attr(fullSize).style(fullSize)

    svg = d3.select "body"
      .append "svg"
      .attr(almostFull).style(almostFull)
      .style border: "1px solid black"

    margin = top: 30, bottom: 30, left: 30, right: 30
    svgSize = getNodeSize svg.node()

    size =
      height: svgSize.height - margin.top - margin.bottom
      width: svgSize.width - margin.left - margin.right

    outerG = @outerG = svg.append "g"
      .attr
        transform: translate(margin.left, margin.top)

    outerG.append "rect"
      .attr size
      .style
        fill: "none"
        stroke: "black"

    @scale = {
      date: d3.time.scale().range([0, size.width])
        .domain [new Date(1e14), new Date()]
      hertz: d3.scale.linear().range([size.height, 0])
        .domain [Infinity, -Infinity]
      amp: d3.scale.linear().range(["#fff", "#00f"])
        .domain [Infinity, -Infinity]
    }

  maybeExpandDomains = (extent, _scale) ->
    for type, _extent of extent
      scale = _scale[type]
      oldDomain = scale.domain()
      if (_extent[0] < oldDomain[0]) and (_extent[1] > oldDomain[1])
        scale.domain _extent
      else if _extent[0] < oldDomain[0]
        scale.domain [_extent[0], oldDomain[1]]
      else if _extent[1] > oldDomain[1]
        scale.domain [oldDomain[0], _extent[1]]

  # maybeExpandDomainsOne = (datum, _scale) ->
  #   debugger

  accessor =
    date: (d) -> d.date
    hertz: (d) -> d.args[0]
    amp: (d) -> d.args[1]

  newData: (newData) ->
    extent =
      date: d3.extent(newData, accessor.date).map (d) -> new Date(d)
      hertz: d3.extent newData, accessor.hertz
      amp: d3.extent newData, accessor.amp

    maybeExpandDomains extent, @scale

    # maybeExpandDomainsOne newData, @scale

    newData.forEach (d) -> d.date = new Date d.date

    mapped = newData.map (d) =>
      date: @scale.date d.date
      amp: @scale.amp d.args[1]
      hertz: @scale.hertz d.args[0]

    packets = packets.concat mapped

    # console.log packets.length

    @updateData newData

  # addCircle = (selection) ->
  #   selection.append("g").classed("point", true)
  #     .append("circle")
  #     .attr r: dotSize
  #     .style
  #       opacity: 0.1
  #       fill: (d) => @scale.amp d.args[1]
  #   return


  updateData: (packets) ->
    point = @outerG.selectAll(".new").data packets
      .enter().append("g").classed("point", true)
      .append("circle").attr r: dotSize
      .style
        opacity: 0.1
        fill: (d) => @scale.amp d.args[1]

    @outerG.selectAll(".point")
      .attr
        transform: (d) =>
          translate @scale.date(d.date), @scale.hertz(d.args[0])

    # point = @outerG.selectAll(".point").data packets
    # point.enter().append("g").classed("point", true)
    #   .attr
    #     transform: (d) =>
    #       translate @scale.date(d.date), @scale.hertz(d.args[0])
    #   .append("circle").attr r: dotSize
    #   .style
    #     opacity: 0.1
    #     fill: (d) => @scale.amp d.args[1]
    # point.attr
    #   transform: (d) =>
    #     translate @scale.date(d.date), @scale.hertz(d.args[0])



class Heatmap
  translate = (x, y) -> "translate(#{x},#{y})"

  cellSize = 10
  rows: rows = 50
  columns: columns = 50

  margin = { top: 30, bottom: 30, left: 30, right: 30 }
  size = { height: cellSize * rows, width: cellSize * columns }

  color = d3.scale.linear().range(["#fff", "#00f"])
  x = d3.scale.ordinal().domain(d3.range columns)
    .rangeBands([0, cellSize * columns])
  y = d3.scale.ordinal().domain(d3.range rows)
    .rangeBands([0, cellSize * rows])

  data = []

  constructor: ->
    outerG = d3.select("body").append("svg")
      .attr({
        height: size.height + margin.top + margin.bottom,
        width: size.width + margin.left + margin.right
      })
      .append "g"
      .attr
        transform: translate(margin.left, margin.top)

    outerG.append "rect"
      .attr size
      .style
        fill: "none"
        stroke: "black"

    @outerG = outerG

  add: (datum) ->
    data.push datum

    @outerG.selectAll(".cell").data(data)
      .enter().append("g").classed("cell", true)
      .each (d, i) ->
        d.x = x(Math.floor(i / rows)) || 0
        d.y = y(i % rows) || 0
      .attr
        transform: (d, i) ->
          translate d.x, d.y
      .append("rect")
      .attr
        width: x.rangeBand()
        height: y.rangeBand()
      .style
        fill: (d) -> color(d.value)



# window.onload = ->
#   heatmap = new Heatmap()
#
#   socket = io()
#
#   socket.on 'new packet', (d) ->
#     # heatmap.add d
#     console.log d
