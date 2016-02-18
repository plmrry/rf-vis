d3 = require 'd3'
THREE = require 'three/three.min'
Rx = require 'rx'
RxDom = require 'rx-dom'
#THREE = require 'three/three'
_ = require 'highland'

#ROTATE_SPEED = 0
#POINT_OPACITY = 0.2
#POINT_SIZE = 15
MAX_POINTS = 1e3
#LOOKAT_OFFSET = 0

watchFrequencies = [
  98e6, 315e6, 433e6, 460e6, 700e6, 800e6,
  850e6, 1700e6, 1900e6, 2140e6, 2437e6, 5250e6
]

accessors =
  x: (d) -> d.date
  y: (d) -> d.args[1].value
  z: (d) -> d.args[0].value

setTimeout (-> do initialize), 0

initialize = () ->
  console.log "Hello buddy man."
  main = d3.select('body').append('main')

  visContainer = main.append("div").classed("vis", true)

  animation = animationObservable().share()

  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Incoming

  socket = do io

  packets = Rx.Observable
    .fromEvent socket, 'new packets'
    # .do (p) -> console.log(p)
    # .do (p) ->
      # console.log Date.now() - p[0].date
    .bufferWithTime 100
    .flatMap (arr) -> arr
    .flatMap (arr) -> arr
    .map setUnscaledValues(accessors)

  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Counter

  counter = main.append("div")
    .style
      position: 'absolute', top: 0, right: 0,
      width: '10rem', 'text-align': 'right'

  packets
    .scan ((a, b) -> a + 1), 0
    .subscribe (d) -> counter.text d

  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Resize

  resize = Rx.Observable.fromEvent window, 'resize'
    .startWith(true)
    .map getSize d3.select("main")

  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Dimensions

  dims = do ->
    _dims = Rx.Observable
      .just getDimensions()
      .combineLatest packets.first()
      .map (arr) ->
        [ dims, p ] = arr
        dims.x.scale.domain [ p.date, p.date + 20 * 1e3 ]
        return dims
    return _dims
      .combineLatest resize
      .map (arr) ->
        [ dims, size ] = arr
        setRange(dims) size
        return dims
      .combineLatest packets
      .map (arr, i) ->
        [ dims, packet ] = arr
        expanded = maybeExpandDomains(dims, ['y', 'z']) packet
        return dims

  #–––––––––––––––––––––––––––––––––––––– One Renderer to Rule them All

  firstRenderer = do ->
    r = new THREE.WebGLRenderer()
    r.setPixelRatio window.devicePixelRatio
    r.setClearColor "white"
    return r
  renderer = resize
    .startWith firstRenderer
    .scan (renderer, r) ->
      renderer.setSize r.width, r.height
      return renderer

  renderer.first().subscribe (renderer) ->
    vis = d3.select(".vis")
    vis.append -> renderer.domElement
    svg = vis.append "svg"
      .style
        position: "absolute", top: 0, left: 0
        height: 2000, width: 2000
    svg.append("g").classed("x axis", true)
    svg.append("g").classed("y axis", true)
    svg.append("g").classed("c1 z axis", true)
    svg.append("g").classed("c2 z axis", true)
    svg.append("g").classed("c3 z axis", true)
    svg.append("g").classed("c4 z axis", true)
    svg.append("g").classed("c5 z axis", true)
    svg.append("g").classed("c6 z axis", true)


  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Particles

  particles = initializeParticles()

  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– mainObject

  mainObject = new THREE.Object3D()
  axisHelper = new THREE.AxisHelper 100
  axisHelper.name = "axis"
  mainObject.add axisHelper
  mainObject.add particles

  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Scene

  scene = (new THREE.Scene()).add mainObject

  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Band Points

  pad = 10e6/2
  band = 10e6/2

  name = "keyfob"
  text = "key fob"
  left = 0.25
  width = 0.25
  fobMid = 315e6

  diff = d3.scale.linear().domain([0, 10]).range([0, 0.9]).clamp(true)

  bandPointsFob =
    addColumn name, text, resize, width, left, fobMid, packets, diff

  #–––––––––––––––––––––––––––––––––––––––––––––––––––– Band Cameras

  cameraXfob = getCameraX animation, dims, fobMid
  cameraYfob = getCameraY animation, dims, fobMid

  #resize.withLatestFrom dims, camera

   #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Band Points

  name = "tmobile"
  text = "t mobile"
  left = 0.5
  width = 0.25
  tmobMid = 2140e6
  diff = d3.scale.linear().domain([0, 10]).range([0, 0.9]).clamp(true)

  bandPointsTmob =
    addColumn name, text, resize, width, left, tmobMid, packets, diff

  #–––––––––––––––––––––––––––––––––––––––––––––––––––– Band Cameras

  cameraXtmob = getCameraX animation, dims, tmobMid
  cameraYtmob = getCameraY animation, dims, tmobMid

  name = "fmradio"
  text = "fm radio"
  left = 0.75
  width = 0.25
  fmMid = 98e6
  diff = d3.scale.linear().domain([0, 10]).range([0, 0.9]).clamp(true)

  bandPointsFm = addColumn name, text, resize, width, left, fmMid, packets, diff

  #–––––––––––––––––––––––––––––––––––––––––––––––––––– Band Cameras

  cameraXfm = getCameraX animation, dims, fmMid
  cameraYfm = getCameraY animation, dims, fmMid

  #–––––––––––––––––––––––––––––––––––––––––––––––––––– Scales

  xFoo = cameraXfob.combineLatest dims, resize

  MOVE = 40

  Rx.Observable.fromEvent(window, 'click')
    .withLatestFrom resize, dims
    .do (arr) ->
      [ e, size, dims ] = arr
      tempZ1 = dims.z.scale.copy()
      tempZ1.domain([fobMid-band, fobMid+band])
        .range([0, size.width * 0.15])
      axis = d3.svg.axis().scale(tempZ1)
        .ticks(3)
        .tickFormat((d) -> d/1e8 + " MHz")
      d3.select(".c1.axis.z").call(axis)
        .attr(
          "transform",
          "translate(#{size.width * 0.30}, #{size.height * 0.66})"
        )
        .call (a) ->
          l = a.selectAll(".label").data([1])
          l.enter().append("text").text("Hertz")
            .classed "label", true
            .attr "transform", "translate(130, 40)"
      tempY = dims.y.scale.copy()
      axisY = d3.svg.axis().scale(tempZ1)
        .ticks(3)
        .tickFormat((d) -> d/1e8 + " dBm")
      d3.select(".axis.y").call(axisY)
        .attr(
          "transform",
          "translate(#{size.width * 0.07}, #{size.height * 0.66})"
        )
        .call (a) ->
          l = a.selectAll(".label").data([1])
          l.enter().append("text").text("Amplitude")
            .classed "label", true
            .attr "transform", "translate(130, 40)"

      tempZ2 = dims.z.scale.copy()
      tempZ2.domain([tmobMid-band, tmobMid+band])
        .range([0, size.width * 0.15])
      axis3 = d3.svg.axis().scale(tempZ2)
        .ticks(3)
        .tickFormat((d) -> d/1e9 + " GHz")
      d3.select(".c3.axis.z").call(axis3)
        .attr(
          "transform",
          "translate(#{size.width * 0.55}, #{size.height * 0.66})"
        )

      tempZ3 = dims.z.scale.copy()
      tempZ3.domain([fmMid-band, fmMid+band])
        .range([0, size.width * 0.15])
      axis4 = d3.svg.axis().scale(tempZ3)
        .ticks(3)
        .tickFormat((d) -> d/1e6 + " MHz")
      d3.select(".c4.axis.z").call(axis4)
        .attr(
          "transform",
          "translate(#{size.width * 0.81}, #{size.height * 0.66})"
        )

    .subscribe()

  #––––––––––––––––––––––––––––––––––––––––––––––––––––– Scale All Points

  allPoints = Rx.Observable.merge bandPointsFob, bandPointsTmob, bandPointsFm

  scaledPoints = allPoints
    .withLatestFrom dims
    .map (arr) ->
      [ p, dims ] = arr
      scalePointByMutation(dims) p

  #–––––––––––––––––––––––––––––––––––––––––––––––––––– Add All Points

  scaledPoints.subscribe (p) ->
    addPointToBuffer(particles) p
    setUpdateFlag particles

  #–––––––––––––––––––––––––––––––––––––––––––––––––––– One Z Camera

  cameraZ = getCameraZ animation, dims

  #dims.withLatestFrom cameraZ
    #.do ->
      #debugger
    #.subscribe()

  #–––––––––––––––––––––––––––––––––––––––––––––––––––– All views

  nullCam = new THREE.OrthographicCamera()
  nullScene = new THREE.Scene()

  views = [
    { left: 0.00, bottom: 0.00, width: 1.00, height: 1.00, scene: nullScene }
    { left: 0.00, bottom: 0.30, width: 0.25, height: 0.70, scene: scene }
    { left: 0.25, bottom: 0.30, width: 0.25, height: 0.70, scene: scene }
    { left: 0.25, bottom: 0.00, width: 0.25, height: 0.30, scene: scene }
    { left: 0.50, bottom: 0.30, width: 0.25, height: 0.70, scene: scene }
    { left: 0.50, bottom: 0.00, width: 0.25, height: 0.30, scene: scene }
    { left: 0.75, bottom: 0.30, width: 0.25, height: 0.70, scene: scene }
    { left: 0.75, bottom: 0.00, width: 0.25, height: 0.30, scene: scene }
  ]

  # Animation
  ###########################################

  animation
    .withLatestFrom(
      renderer,
      resize,
      cameraZ,
      cameraYfob,
      cameraXfob,
      cameraYtmob,
      cameraXtmob
      cameraYfm, cameraXfm
    )
    .subscribe (arr) ->
      [
        time, renderer, size, cameraZ, cameraYfob, cameraXfob,
        cameraYtmob, cameraXtmob, cameraYfm, cameraXfm
      ] = arr
      
      views[0].camera = nullCam
      views[1].camera = cameraZ

      views[2].camera = cameraYfob
      views[3].camera = cameraXfob

      views[4].camera = cameraYtmob
      views[5].camera = cameraXtmob

      views[6].camera = cameraYfm
      views[7].camera = cameraXfm

      views.forEach (v, i) ->
        left = size.width * v.left
        bottom = size.height * v.bottom
        width = size.width * v.width
        height = size.height * v.height

        renderer.setViewport left, bottom, width, height
        renderer.setScissor left, bottom, width, height
        renderer.enableScissorTest true

        renderer.render v.scene, v.camera

getCameraViews = (left, width, scene, animation, dims, mid) ->
  cX = getCameraX animation, dims, mid
  cY = getCameraY animation, dims, mid
  return [
    {
      left: left,
      bottom: 0.25,
      width: width,
      height: 0.75,
      camera: cY,
      scene: scene
    },
    {
      left: left,
      bottom: 0.00,
      width: width,
      height: 0.25,
      camera: cX,
      scene: scene
    }
  ]

getBandViews = (left, width) ->
  return [
    { left: left, bottom: 0.25, width: width, height: 0.75 }
    { left: left, bottom: 0.00, width: width, height: 0.25 }
  ]

newPoint = (type, x, y, z) ->
  date: Date.now()
  alpha: 1.0
  unscaled:
    x: x, y: y, z: z
  type: type

flatMapAverage = (source) ->
  (property) ->
    source.flatMap (arr) -> arr.average (d) -> d.unscaled[property]

combineToPoint = (a, b, c) ->
  (type) ->
    Rx.Observable
      .combineLatest b, c
      .withLatestFrom a
      .map (arr) ->
        [ [ y, z ], o] = arr
        x = o.unscaled.x
        newPoint type, x, y, z

addColumn = (name, text, resize, width, left, mid, packets, diffScale) ->
  addEventText name, text
  resize.subscribe (size) ->
    d3.select(".#{name}")
      .style
        width: size.width * width
        height: size.height
        top: 0
        left: size.width * left
  pad = 10e6/2
  band = 10e6/2
  low = mid-band-pad
  high = mid+band+pad
  thisBand = packets
    .filter (d) ->
      z = d.unscaled.z
      (z > low) and (z < high)
  trailing = thisBand.windowWithCount 100, 10
  avgAmp = flatMapAverage(trailing)('y')
  avgHz = flatMapAverage(trailing)('z')
  avgPoint = combineToPoint(thisBand, avgAmp, avgHz)("average")
    .distinct (d) -> d.unscaled.x
  maxAmpPoint = thisBand.windowWithTime 1000
    .flatMap (arr) -> arr.maxBy (d) -> d.unscaled.y
    .map (m) -> m[0]
    .filter (m) -> m?
    .map (m) ->
      { x, y, z } = m.unscaled
      newPoint "max", x, y, z
    .distinct (d) -> d.unscaled.x
  maxAmpWindow = maxAmpPoint.windowWithCount 8, 1
  maxAmpAvgAmp = flatMapAverage(maxAmpWindow)('y')
  maxAmpAvgHz = flatMapAverage(maxAmpWindow)('z')
  maxAmpAvgPoint = Rx.Observable
    .combineLatest avgPoint, maxAmpAvgAmp, maxAmpAvgHz
    .map (arr) ->
      [ o, y, z ] = arr
      x = o.unscaled.x
      newPoint "maxAverage", x, y, z
    .distinct (d) -> d.unscaled.x
  events = maxAmpPoint
    .withLatestFrom maxAmpAvgPoint
    .filter (arr) ->
      [packet, max] = arr
      packet.unscaled.y > max.unscaled.y
    .map (arr) ->
      [packet, max] = arr
      packet.diff = packet.unscaled.y - max.unscaled.y
      packet.type = "event"
      return packet
    .share()
  events.subscribe (p) ->
    a = diffScale p.diff
    console.log "Event", name, "diff", p.diff, "scaled", a
    d3.select(".#{name}")
      .interrupt()
      .style "opacity": a
      .transition()
      .duration(a * 5000)
      .style "opacity": 0
  trends = Rx.Observable.merge avgPoint, maxAmpPoint, maxAmpAvgPoint, events
  bandPoints = Rx.Observable.merge thisBand, trends
  return bandPoints

addEventText = (name, text) ->
  d3.select(".vis")
    .append("div").classed(name, true)
    .style
      "background-color": "red"
      opacity: 0
      position: 'absolute'
    .append("div")
    .style
      "font-size": "7em"
      "color": "white"
      "-webkit-transform": "rotate(90deg)"
      position: "absolute"
      top: "200px"
      "white-space": "nowrap"
    .html text

getCameraZ = (animation, dims, packet) ->
  cameraPosition = animation
    .withLatestFrom dims
    .startWith new THREE.Vector3 0, 0, 1000
    .scan (position, arr) ->
      [ anim, dims ] = arr
      date = Date.now() - 2e3
      position.setX dims.x.scale(date)
      return position
  cameraSize = dims.map (dims) ->
    x = 200
    y = 200
    bottom: -y
    top: y
    left: -x
    right: x
  cameraLookAt = animation
    .withLatestFrom dims
    .startWith new THREE.Vector3 0, 0, 0
    .scan (position, arr) ->
      [ anim, dims ] = arr
      date = Date.now() - 2e3
      position.setX dims.x.scale(date)
      return position
  cameraUp = Rx.Observable.just new THREE.Vector3(-1, 0, 0)
  getCamera cameraSize, cameraPosition, cameraLookAt, cameraUp

getCameraY = (animation, dims, mid) ->
  cameraPosition = animation
    .withLatestFrom dims
    .startWith new THREE.Vector3 0, 1000, 0
    .scan (position, arr) ->
      [ anim, dims, packet ] = arr
      date = Date.now() - 2e3
      position.setX dims.x.scale(date)
      position.setZ dims.z.scale(mid)
      return position
  cameraSize = dims.map (dims) ->
    x = 3
    y = 200
    bottom: -y
    top: y
    left: -x
    right: x
  cameraLookAt = animation
    .withLatestFrom dims
    .startWith new THREE.Vector3 0, 0, 0
    .scan (position, arr) ->
      [ anim, dims, packet ] = arr
      date = Date.now() - 2e3
      position.setX dims.x.scale(date)
      position.setZ dims.z.scale(mid)
      return position
  cameraUp = Rx.Observable.just new THREE.Vector3(-1, 0, 0)
  getCamera cameraSize, cameraPosition, cameraLookAt, cameraUp

# @needs animation, dims, mid
getCameraX = (animation, dims, mid) ->
  cameraPosition = animation
    .withLatestFrom dims
    .startWith new THREE.Vector3 1000, 0, 0
    .scan (position, arr) ->
      [ anim, dims ] = arr
      date = Date.now()
      position.setX dims.x.scale(date) + 1000
      position.setZ dims.z.scale(mid)
      return position
  cameraSize = dims.map (dims) ->
    y = 300
    x = 3
    bottom: -y - 50
    top: y
    left: -x
    right: x
  cameraLookAt = animation
    .withLatestFrom dims
    .startWith new THREE.Vector3 0, 0, 0
    .scan (position, arr) ->
      [ anim, dims ] = arr
      date = Date.now()
      position.setX dims.x.scale(date)
      position.setZ dims.z.scale(mid)
      return position
  cameraUp = Rx.Observable.just new THREE.Vector3(0, 1, 0)
  getCamera cameraSize, cameraPosition, cameraLookAt, cameraUp

getCamera = (cameraSize, cameraPosition, cameraLookAt, cameraUp) ->
  return Rx.Observable
    .combineLatest(
      cameraSize, cameraPosition, cameraLookAt, cameraUp
    )
    .startWith new THREE.OrthographicCamera()
    .scan (camera, arr) ->
      [ size, pos, lookAt, up ] = arr
      [ 'left', 'right', 'top', 'bottom' ].forEach (k) ->
        if size[k]? then camera[k] = size[k]
      camera.updateProjectionMatrix()
      if pos? then camera.position.copy pos
      if up? then camera.up.set up.x, up.y, up.z
      if lookAt? then camera.lookAt lookAt
      return camera

setUpdateFlag = (particles) ->
  ->
    geometry = particles.geometry
    geometry.verticesNeedUpdate = true

getDimensions = ->
  obj =
    x:
      name: 'time'
      accessor: (d) -> d.date
    y:
      name: 'amp'
      accessor: (d) -> d.args[1].value
    z:
      name: 'freq'
      accessor: (d) -> d.args[0].value
    color: {}
    alpha: d3.scale.linear().range([0.05, 0.10])
    size: d3.scale.linear().range([5.0, 40.0])
    diff: d3.scale.linear().domain([0, 10])
  for key, value of obj
    value.scale = d3.scale.linear().domain([Infinity, -Infinity])
  #obj.x.scale.domain [Date.now(), Date.now() + 1e3 * 20]
  return obj

maybeExpandDomains = (dims, which) ->
  (point) ->
    changed = false
    for dim in which
      s = dims[dim].scale
      p = point.unscaled[dim]
      if p < s.domain()[0]
        s.domain [ p, s.domain()[1] ]
        changed = true
      if p > s.domain()[1]
        s.domain [ s.domain()[0], p ]
        changed = true
    dims.alpha.domain dims.y.scale.domain()
    dims.size.domain dims.y.scale.domain()
    return changed

setUnscaledValues = (accessors) ->
  (packet) ->
    packet.unscaled = {}
    for dim, accessor of accessors
      packet.unscaled[dim] = accessor packet
    packet.color = new THREE.Vector3()
    return packet

scalePointByMutation = (dims) ->
  (point) ->
    point.x = dims.x.scale point.unscaled.x
    point.y = dims.y.scale point.unscaled.y
    point.z = dims.z.scale point.unscaled.z
    point.alpha = dims.alpha point.unscaled.y
    point.size = dims.size point.unscaled.y
    if point.type is "average"
      #point.color = new THREE.Vector3 1, 0, 0
      point.size = 10.0
      point.alpha = 1.0
    if point.type is "max"
      #point.color = new THREE.Vector3 0, 0, 1
      point.size = 10.0
      point.alpha = 1.0
      #point.alpha = 0
    if point.type is "maxAverage"
      #point.color = new THREE.Vector3 0, 1, 0
      point.size = 10.0
      point.alpha = 1.0
    if point.type is "event"
      point.color = new THREE.Vector3 1, 0, 0
      # point.alpha = dims.diff point.diff
      point.alpha = 1
    return point

addPointToBuffer = (particles) ->
  # Particles is a THREE.Points object
  (point) ->
    geometry = particles.geometry
    vertices = geometry._vertices # "virtual" vertices array
    if geometry.nextEmptyVertex >= vertices.length
      geometry.nextEmptyVertex = 0
    next = geometry.nextEmptyVertex
    geometry._vertices[next] = point
    positions = geometry.getAttribute 'position'
    positions.setXYZ next, point.x, point.y, point.z
    positions.needsUpdate = true
    colors = geometry.getAttribute 'color'
    c = point.color or new THREE.Vector3(0, 0, 0)
    colors.setXYZ next, c.x, c.y, c.z
    colors.needsUpdate = true
    alphas = geometry.getAttribute 'alpha'
    a = point.alpha
    alphas.setX next, a
    alphas.needsUpdate = true
    size = geometry.getAttribute 'size'
    size.setX next, point.size
    size.needsUpdate = true
    geometry.nextEmptyVertex++

initializeParticles = ->
  maxPoints = MAX_POINTS
  pointsGeom = new THREE.Geometry()
  pointsGeom.vertices = d3.range(maxPoints).map -> new THREE.Vector3()
  bufferGeom = getBufferGeometry pointsGeom
  bufferGeom._vertices = pointsGeom.vertices
  bufferGeom.nextEmptyVertex = 0
  shader = THREE.ShaderLib['donaldTrump']
  shaderMaterial = new THREE.ShaderMaterial
    uniforms: shader.uniforms
    vertexShader: shader.vertexShader
    fragmentShader: shader.fragmentShader
    transparent: true
    depthWrite: false
    vertexColors: THREE.VertexColors
  particles = new THREE.Points bufferGeom, shaderMaterial
  particles.frustumCulled = false
  return particles

animationObservable = ->
  Rx.Observable.generate(
    0,
    -> true,
    (x) -> x + 1,
    (x) -> x,
    Rx.Scheduler.requestAnimationFrame
  ).timestamp()

getSize = (selection) ->
  ->
    size = getSizeFrom selection.node()
    size.x = size.width
    size.y = size.height * 0.5
    size.z = size.width
    return size

getSizeFrom = (element) ->
  size =
    width: element.clientWidth
    height: element.clientHeight
  return size

setRange = (dims) ->
  (size) ->
    for dim, obj of dims
      s = size[dim]/2
      obj.scale.range [-s, s]

getBufferGeometry = (pointsGeom) ->
  geom = new THREE.BufferGeometry()
  vertices = pointsGeom.vertices
  flattened = vertices
    .map (v) -> v.toArray()
    .reduce (a, b) -> a.concat b
  positions = flattened
  geom.addAttribute 'position', new THREE.Float32Attribute positions, 3
  colors = vertices
    .map (v) -> v.toArray()
    .reduce (a, b) -> a.concat b
  geom.addAttribute 'color', new THREE.Float32Attribute colors, 3
  alphas = vertices.map -> 0
  geom.addAttribute 'alpha', new THREE.Float32Attribute alphas, 1
  sizes = vertices.map -> 0
  geom.addAttribute 'size', new THREE.Float32Attribute sizes, 1

  return geom

THREE.ShaderLib['donaldTrump'] = {
  uniforms: {
    pointTexture: {
      type: "t", value: THREE.ImageUtils.loadTexture( "/spark1.png" )
    }
  },
  vertexShader: [
    "attribute float alpha;"
    "attribute float size;"
    "varying float vAlpha;"
    "varying vec3 vColor;"
    "void main() {",
    "vColor = color;"
      "vAlpha = alpha;"
      "gl_PointSize = size;"
      "vec4 mvPosition = modelViewMatrix * vec4( position, 1.0 );"
      "gl_Position = projectionMatrix * mvPosition;"
    "}"
  ].join( "\n" ),
  fragmentShader: [
    "varying vec3 vColor;"
    "varying float vAlpha;"
    "uniform sampler2D pointTexture;"
    "void main() {",
      "gl_FragColor = vec4( vColor.rgb, vAlpha );",
      "gl_FragColor = gl_FragColor * texture2D( pointTexture, gl_PointCoord );"
    "}"
  ].join( "\n" )
}


  #timeAlphaScale = d3.scale.linear()
    #.domain [ 60e3, 65e3 ]
    #.range [ 1, 0 ]
    #.clamp true
  #
  #packets.subscribe (d) ->
     #Latest packet date
    #latestDate = Date.now()
    #
     #Particle dates
    #geom = particles.geometry
    #alphas = geom.getAttribute('alpha')
    #geom._vertices
      #.forEach (d, i) ->
        #return if not d.date?
        #dt = latestDate - d.date
        #a = timeAlphaScale(dt) * d.alpha
        #alphas.setX i, a
    #alphas.needsUpdate = true
