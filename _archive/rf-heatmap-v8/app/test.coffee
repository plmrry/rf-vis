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
  98e6, 315e6, 433e6, 460e6, 700e6, 800e6, 850e6, 1700e6, 1900e6, 2140e6, 2437e6, 5250e6
]

accessors =
  x: (d) -> d.date
  y: (d) -> d.args[1].value
  z: (d) -> d.args[0].value

setTimeout (-> do initialize), 0

initialize = () ->
  console.log "Hello test."
  main = d3.select('body').append('main')
  
  visContainer = main.append("div")
    .classed("vis", true)
  
  counter = main.append("div")
    .style 
      position: 'absolute', top: 0, right: 0, 
      width: '10rem', 'text-align': 'right'
      
  animation = animationObservable().share()
  
  # Packets
  ##########################################
  
  socket = do io
  
  packets = Rx.Observable
    .fromEvent socket, 'new packets'
    .bufferWithTime 100
    .flatMap (arr) -> arr
    .flatMap (arr) -> arr
    .map setUnscaledValues(accessors)
    
  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Counter
      
  packets
    .scan ((a, b) -> a + 1), 0
    .subscribe (d) -> counter.text d
    
  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Resize
  
  resize = Rx.Observable.fromEvent window, 'resize'
    .startWith(true)
    .map getSize d3.select("main")
    #.share()
    
  #d3.select(".vis").append("div").classed("keyfob", true)
    
  #resize.first().subscribe (size) ->
    #d3.select.append("div")
      #.classed("keyfob", true)
      #.style 
        #border: "1px solid red"
        #width: size.width
        #height: size.height
    
  # Dimensions
  #########################################
  
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
        #if i > 20e3 then return dims
        [ dims, packet ] = arr
        expanded = maybeExpandDomains(dims, ['y', 'z']) packet
        #if expanded then console.log "dims expanded"
        return dims
    
  # Renderer
  #########################################
      
  firstRenderer = do ->
    r = new THREE.WebGLRenderer()
    r.setPixelRatio window.devicePixelRatio
    r.setClearColor "white"
    return r
  rendererEvents = Rx.Observable.merge(resize)
  renderer = rendererEvents
    .startWith firstRenderer
    .scan (renderer, r) ->
      renderer.setSize r.width, r.height
      return renderer
      
  renderer.first().subscribe (renderer) ->
    d3.select(".vis").append -> renderer.domElement
    d3.select(".vis")
      .append("div").classed("keyfob", true)
      .style 
        "background-color": "red"
        "opacity": 0
      .append("p").style
        "font-size": "10em"
        "color": "white"
      
  resize.subscribe (size) ->
    d3.select(".keyfob").style
      #border: "1px solid red"
      width: size.width
      height: size.height/3
      position: 'absolute'
      top: size.height/3
      left: 0
      
  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Particles  
    
  particles = initializeParticles()
  
  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– mainObject  
  
  mainObject = do ->
    axisHelper = new THREE.AxisHelper 100 
    axisHelper.name = "axis"
    mainObject = new THREE.Object3D()
    mainObject.name = 'main'
    #mainObject.add axisHelper
    return mainObject
  mainObject.add particles
      
  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Scene  
  
  scene = (new THREE.Scene()).add mainObject
  
  # Filtered
  ############################
  
  #––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– EVIL SHIT
  
  name = "key fob"
    
  
  pad = 10e6/2
  band = 10e6/2
  #mid = 850e6
  mid = 315e6
  low = mid-band-pad
  high = mid+band+pad

  thisBand = packets
    .filter (d) -> 
      z = d.unscaled.z
      (z > low) and (z < high)
      
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
      
  trailing = thisBand.windowWithCount 100, 10
  keyFobAvgAmp = flatMapAverage(trailing)('y')
  keyFobAvgHz = flatMapAverage(trailing)('z')
    
  avgPoint = combineToPoint(thisBand, keyFobAvgAmp, keyFobAvgHz)("average")
    .distinct (d) -> d.unscaled.x
  
  maxAmpPoint = thisBand.windowWithTime 1000
    .flatMap (arr) -> arr.maxBy (d) -> d.unscaled.y
    .map (m) -> m[0] 
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
    
  diffScale = d3.scale.linear().domain([0, 10]).range([0, 0.9]).clamp(true)
  events.subscribe (p) ->
    a = diffScale p.diff
    console.log p.diff, a
    
    d3.select(".keyfob")
      .select "p"
      .text "key fob"
      .style opacity: 1
      
    d3.select(".keyfob")
      .interrupt()
      #.transition()
      #.style "background-color": "rgba(255, 0, 0, 0)"
      #.call (s) -> s.select("p").style "opacity": 1
      #.transition().duration(10)
      #.style "background-color": "rgba(255, 0, 0, #{a})"
      .style "opacity": a
      .transition()
      .duration(a * 5000)
      .style "opacity": 0
      #.style "background-color": "rgba(255, 0, 0, 0)"
      #.select("p").style "opacity": 0
      #.each "end", -> 
        #d3.select(this).select("p").text("")
  
  trends = Rx.Observable.merge(
    avgPoint, maxAmpPoint, maxAmpAvgPoint, events
  )
      
  allPoints = Rx.Observable.merge(
    thisBand, trends
  )
  
  #–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– Add points

  allPoints.withLatestFrom dims
    .map (arr) ->
      [ p, dims ] = arr
      scalePointByMutation(dims) p
    .subscribe (p) ->
      addPointToBuffer(particles) p
      setUpdateFlag particles
      
  #################################################### Cameras
    
  trackX = (offset) ->
    (position, arr) ->
      [ anim, dims, packet ] = arr
      date = Date.now() - 60e3 + offset
      position.setX dims.x.scale(date)
      return position
      
  cameraZ = do ->
    cameraPosition = animation
      .withLatestFrom dims
      .startWith new THREE.Vector3 0, 0, 1000
      .scan (position, arr) ->
        [ anim, dims, packet ] = arr
        date = Date.now() - 60e3
        position.setX dims.x.scale(date)
        return position
    cameraSize = dims.map (dims) ->
      bottom: dims.y.scale.range()[0]
      top: dims.y.scale.range()[1]
      left: dims.x.scale.range()[0]
      right: dims.x.scale.range()[1]
    cameraLookAt = animation
      .withLatestFrom dims
      .startWith new THREE.Vector3 0, 0, 0
      .scan trackX(0)
    cameraUp = Rx.Observable.just new THREE.Vector3(0, 1, 0)
    getCamera cameraSize, cameraPosition, cameraLookAt, cameraUp
    
  cameraY = do ->
    cameraPosition = animation
      .withLatestFrom dims
      .startWith new THREE.Vector3 0, 1000, 0
      .scan (position, arr) ->
        [ anim, dims, packet ] = arr
        date = Date.now() - 60e3
        position.setX dims.x.scale(date)
        position.setZ dims.z.scale(mid)
        return position
    cameraSize = dims.map (dims) ->
      y = 2
      bottom: -y
      top: y
      left: dims.x.scale.range()[0]
      right: dims.x.scale.range()[1]
    cameraLookAt = animation
      .withLatestFrom dims
      .startWith new THREE.Vector3 0, 0, 0
      .scan (position, arr) ->
        [ anim, dims, packet ] = arr
        date = Date.now() - 60e3
        position.setX dims.x.scale(date)
        position.setZ dims.z.scale(mid)
        return position
    cameraUp = Rx.Observable.just new THREE.Vector3(0, 0, -1)
    getCamera cameraSize, cameraPosition, cameraLookAt, cameraUp
    
  cameraX = do ->
    cameraPosition = animation
      .withLatestFrom dims
      .startWith new THREE.Vector3 1000, 0, 0
      .scan (position, arr) ->
        [ anim, dims, packet ] = arr
        date = Date.now() - 60e3
        position.setX dims.x.scale(date) + 1000
        position.setZ dims.z.scale(mid)
        return position
    cameraSize = dims.map (dims) ->
      y = 2
      x = 200
      bottom: -y
      top: y
      left: -x
      right: x
    cameraLookAt = animation
      .withLatestFrom dims
      .startWith new THREE.Vector3 0, 0, 0
      .scan (position, arr) ->
        [ anim, dims, packet ] = arr
        date = Date.now() - 60e3
        #position.setX dims.x.scale(date)
        position.setZ dims.z.scale(mid)
        return position
    cameraUp = Rx.Observable.just new THREE.Vector3(0, 0, -1)
    getCamera cameraSize, cameraPosition, cameraLookAt, cameraUp
      
  views = [
    { left: 0, bottom: 0.000, width: 0.75, height: 0.333 }
    { left: 0, bottom: 0.333, width: 0.75, height: 0.333 }
    { left: 0.75, bottom: 0.333, width: 0.25, height: 0.333 }
  ]
    
  # Animation
  ###########################################
  
  nullCam = new THREE.OrthographicCamera()
  nullScene = new THREE.Scene()
  
  animation.withLatestFrom(
      renderer, resize, cameraZ, cameraY, cameraX
    )
    .subscribe (arr) ->
      [ time, renderer, size, cameraZ, cameraY, cameraX ] = arr
      renderer.setViewport 0, 0, size.width, size.height
      renderer.setScissor 0, 0, size.width, size.height
      renderer.render nullScene, nullCam
      views[0].camera = cameraZ
      views[1].camera = cameraY
      views[2].camera = cameraX
      views.forEach (v, i) ->
        left = size.width * v.left
        bottom = size.height * v.bottom
        width = size.width * v.width
        height = size.height * v.height
        renderer.setViewport left, bottom, width, height
        renderer.setScissor left, bottom, width, height
        renderer.enableScissorTest true
        renderer.render scene, v.camera
        
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
      point.alpha = dims.diff point.diff
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
	  pointTexture: { type: "t", value: THREE.ImageUtils.loadTexture( "/spark1.png" ) }  
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
};


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