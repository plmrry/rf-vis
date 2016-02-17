
# coffeelint: disable=no_debugger

# Queue = require 'fastqueue'

setTimeout (-> do go), 0

go = ->
  dots = new Dots()
  # dots.startInterval()

  socket = io()
  socket.on 'new packet', dots.newData

class Dots
  translate = (x, y) -> "translate(#{x},#{y})"
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
      date: d3.scale.linear().range [0, size.width]
        .domain [Infinity, -Infinity]
      # date: d3.time.scale().range([0, size.width])
        # .domain [Infinity, -Infinity]
        # .domain [new Date(1e14), new Date()]
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

  accessor =
    date: (d) -> d.date
    hertz: (d) -> d.args[1]
    amp: (d) -> d.args[2]

  newData: (newData) ->
    # queue.push newData

  queue = []

  startInterval: ->
    @interval = setInterval =>
      @shiftQueue()
      @shiftQueue()
      @shiftQueue()
      @shiftQueue()
      @shiftQueue()
      @shiftQueue()
    , 0

  shiftQueue: =>
    point = queue.shift()
    if point?
      @processPoint point
      @addPoint point
    # console.log queue.length

  # Example: "10/6/2015 1:58:32 AM"
  # format = d3.time.format "%-m/%-d/%Y "

  processPoint: (point) ->
    newData = [point]

    extent =
      date: d3.extent newData, accessor.date
      hertz: d3.extent newData, accessor.hertz
      amp: d3.extent newData, accessor.amp

    maybeExpandDomains extent, @scale

  addPoint: (point) =>
    @outerG.append("g").classed("point", true)
      .datum point
      .append("circle")
      .attr r: dotSize
      .style
        opacity: 0.5
        fill: (d) => @scale.amp accessor.amp point

    scale = @scale

    @outerG.selectAll(".point")
      .attr
        transform: (d) ->
          x = scale.date accessor.date d
          y = scale.hertz accessor.hertz d
          translate x, y
