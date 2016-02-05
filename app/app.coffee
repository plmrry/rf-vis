d3 = require 'd3'
THREE = require 'three/three.min'
#THREE = require 'three/three'
_ = require 'highland'

ROTATE_SPEED = 0
POINT_OPACITY = 0.2
POINT_SIZE = 15
MAX_POINTS = 10e3
LOOKAT_OFFSET = 0

watchFrequencies = [
  98e6, 315e6, 433e6, 460e6, 700e6, 800e6, 850e6, 1700e6, 1900e6, 2140e6, 2437e6, 5250e6
]

setTimeout (-> do initialize), 0

initialize = () ->
  console.log "Hello dude."
  { main, camera, scene, renderer } = do addStuff
  counter = main.append("div")
    .style 
      position: 'absolute', top: 0, left: 0, 
      width: '10rem', 'text-align': 'right'
  # UGHHHHH
  window.dims = getDimensions()
  console.log dims
  particles = do initializeParticles
  # Important – Our object is going to get very long!
  particles.frustumCulled = false
  mainObj = scene.getObjectByName 'main'
  mainObj.add particles
  socket = do io
  resize = _ 'resize', d3.select window
  
  resizeStream = _([ _([true]), resize ]).merge()
    .map getSize(main)
    .doto setCameraSize camera
    .doto setRenderSize renderer
    .doto updateHelpers scene
    .doto setRange dims
    .done()
    
  i = 0
  
  pad = 10e6/2
  band = 10e6/2
  mid = 850e6
  unscaledValues = _ 'new packets', socket
    .map (d) -> d[0]
    .map setPacketUnscaledValues dims
    #.filter (d) ->
      #hz = d.args[0].value
      #(hz > mid-band-pad)
    
  expand =
    y: scale: dims.y.scale
    z: scale: dims.z.scale
    
  latestDate = Date.now()
  unscaledValues
    .observe()
    .map (p) -> 
      p.date
    .each (d) -> latestDate = d
    
  once = true
  
  unscaledValues
    .doto (p) -> 
      if once
        dims.x.scale.domain [ p.date, p.date + 20 * 1e3 ]
        once = false
    .map maybeExpandDomains(expand, ['y', 'z'])
    .filter (d) -> d is true
    .done()
    
  unscaledValues.fork()
    .doto scalePointByMutation dims
    #.map addPoint particles
    .map addPointToBuffer particles
    .doto setUpdateFlag particles
    .done()
    
  unscaledValues.fork().map -> 1
    .scan 0, _.add
    .each (d) -> counter.text d
    
  # Each animation frame
  _(frameGenerator).each ->
    mainObj.rotateY degToRad ROTATE_SPEED
    latestX = dims.x.scale Date.now() - 50e3
    #console.log Date.now() - latestDate
    #latestX = dims.x.scale Date.now()
    
    # Always look at latest x. Others may vary!
    lookAt = new THREE.Vector3 latestX + LOOKAT_OFFSET, camera._lookAt.y, camera._lookAt.z
    
    camera.position.setX latestX
    camera.lookAt lookAt
    renderer.render scene, camera
    
degToRad = d3.scale.linear()
  .domain [0, 360]
  .range [0, 2 * Math.PI]
  
scalePointByMutation = (dims) ->
  (point) ->
    for dim, obj of dims
      point[dim] = obj.scale point.unscaled[dim]
    return point
    
setRange = (dims) ->
  (size) ->
    for dim, obj of dims
      s = size[dim]/2
      obj.scale.range [-s, s]
      
setUpdateFlag = (particles) ->
  ->
    geometry = particles.geometry
    geometry.verticesNeedUpdate = true
    
    
pad = 10e6/2
band = 10e6/2
mid = 850e6
low = mid-pad-band
high = mid+pad+band

#unscaledValues = _ 'new packet', socket
  #.map setPacketUnscaledValues dims
    #.filter (d) ->
      #hz = d.args[0].value
      #(hz > mid-band-pad)
    
addPointToBuffer = (particles) ->
  # Particles is a THREE.Points object
  (point) ->
    geometry = particles.geometry
    
    v = point.args[0].value
    return if (v < low) or (v > high)
    
    positions = geometry.getAttribute 'position'
    if geometry.nextEmptyVertex > positions.count
      geometry.nextEmptyVertex = 0
    next = geometry.nextEmptyVertex
    
    geometry._vertices[next] = point
    positions.setXYZ next, point.x, point.y, point.z
    
    colors = geometry.getAttribute 'color'
    #if Math.random() < 0.01
      #console.log window.dims.y.scale.domain()
      #console.log point.y
    c = globalColor point.unscaled.y
    #console.log c.r
    colors.setXYZ next, c.r, c.g, c.b
    
    alphas = geometry.getAttribute 'alpha'
    a = globalAlpha point.unscaled.y
    alphas.setX next, a
    alphas.needsUpdate = true
    
    scales = geometry.getAttribute 'scale'
    s = globalSize point.unscaled.y
    scales.setX next, s
    scales.needsUpdate = true
    
    geometry.nextEmptyVertex++
    positions.needsUpdate = true
    colors.needsUpdate = true
    
r = [new THREE.Color(0,0,0), new THREE.Color(0,0,0), new THREE.Color(3,0,0)]
#r = [new THREE.Color(0,0,0), new THREE.Color(1,0,0)]
globalColor = d3.scale.linear().range r
globalAlpha = d3.scale.pow().exponent(5).range [0, 1]
globalSize = d3.scale.pow().exponent(2).range [2, 30]
    
maybeExpandDomains = (dims) ->
  (point) ->
    changed = false
    for dim, obj of dims
      s = obj.scale
      p = point.unscaled[dim]
      if p < s.domain()[0]
        s.domain [ p, s.domain()[1] ]
        changed = true
      if p > s.domain()[1]
        s.domain [ s.domain()[0], p ]
        changed = true
    
    if changed
      d = dims.y.scale.domain()
      m = d[1] - ((d[1]-d[0]) * 0.6)
      globalColor.domain [d[0], m, d[1]]
      globalAlpha.domain d
      globalSize.domain d
    return changed
    
setPacketUnscaledValues = (dimensions) ->
  (packet) ->
    packet.unscaled = {}
    for dim, obj of dimensions
      packet.unscaled[dim] = obj.accessor packet
    return packet
    
frameGenerator = (push, next) ->
  x = ->
    requestAnimationFrame x
    push()
  do x

getSize = (main) ->
  ->
    size = getSizeFrom main.node()
    size.x = size.width
    size.y = size.height * 0.5
    size.z = size.width
    return size
    
updateHelpers = (scene) ->
  (size) ->
    main = scene.getObjectByName 'main'
    grid = main.getObjectByName 'grid'
    main.remove grid
    grid = new THREE.GridHelper size.width/2, 100
    grid.name = 'grid'
    main.add grid
    
setRenderSize = (renderer) ->
  (size) ->
    renderer.setSize size.width, size.height
    
setCameraSize = (camera) ->
  (size) ->
    [ w, h ] = [ 'width', 'height' ].map (k) -> size[k] * 0.5
    [ camera.left, camera.right ] = [ -w, w ].map (d) -> d * 1.5
    [ camera.top, camera.bottom ] = [ h, -h ].map (d) -> d * 0.7
    camera.updateProjectionMatrix()
    ['top', 'bottom'].forEach (side) ->
      n = d3.select("input.camera.#{side}")
      n.node().value = camera[side]
    
getSizeFrom = (element) ->
  size =
    width: element.clientWidth
    height: element.clientHeight
  return size
  
initializeParticles = ->
  maxPoints = MAX_POINTS
  
  pointsGeom = new THREE.Geometry()
  pointsGeom.nextEmptyVertex = 0
  pointsGeom.vertices = d3.range(maxPoints).map () -> 
    p = new THREE.Vector3()
    p.alpha = 1.0
    return p
    
  bufferGeom = getBufferGeometry pointsGeom
  bufferGeom._vertices = pointsGeom.vertices
  bufferGeom.nextEmptyVertex = 0
  
  window.globalGeom = bufferGeom
  
  shader = THREE.ShaderLib['donaldTrump']
  
  shaderMaterial = new THREE.ShaderMaterial
    uniforms: shader.uniforms
    vertexShader: shader.vertexShader
    fragmentShader: shader.fragmentShader
    transparent: true
    depthWrite: false
    vertexColors: THREE.VertexColors

  #particles = new THREE.Points pointsGeom, pointsMaterial
  particles = new THREE.Points bufferGeom, shaderMaterial
  return particles
  
addStuff = ->
  axisHelper = new THREE.AxisHelper 100 
  axisHelper.name = "axis"
  
  mainObject = new THREE.Object3D()
  mainObject.name = 'main'
  mainObject.add axisHelper
  
  scene = new THREE.Scene()
  scene.add mainObject

  camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10e3)
  camera.position.copy new THREE.Vector3 300, 200, 2000
  camera._lookAt = new THREE.Vector3
  
  window.cam = camera
  
  #camera.lookAt camera._lookAt

  renderer = new THREE.WebGLRenderer()
  renderer.setPixelRatio window.devicePixelRatio
  renderer.setClearColor "white"

  main = d3.select('body').append('main')
  visContainer = main.append("div")
    .classed("vis", true)
    .append -> renderer.domElement
    
  ####################################################
  # TEMPORARY CONTROLS
  #
  #
  #
    
  controls = main.append("div")
    .classed("controls", true)
    
  ['x', 'y', 'z'].forEach (dim) ->
    c = controls.append "div"
    c.append "input"
      .attr
        type: "range"
        min: -3000
        max: 3000
        value: camera.position[dim]
      .on "mousedown", ->
        t = d3.select(this.parentNode).select("span")
        input = d3.select(this)
        input.on "mousemove", ->
          camera.position[dim] = this.value
          t.text this.value
        #input.on "mousemove", setPosition dim, this.value, t
        #input.on "change", setPosition dim, this.value, t
        input.on "mouseup", ->
          input.on "mousemove", null
    c.append("span").text dim
    
  ['top', 'bottom'].forEach (side) ->
    c = controls.append "div"
    c.append "input"
      .classed "camera #{side}", true
      .attr
        value: camera[side]
      .on "change", ->
        camera[side] = parseInt this.value
        camera.updateProjectionMatrix()
    c.append("span").text camera[side]
          
  buttons = controls.append "div"
  
  #buttons.append "button"
    #.text "lookat"
    #.on "click", ->
      #camera.lookAt new THREE.Vector3()
      
  buttons.append "button"
    .text "y=1 z=2000"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraYZTween(camera, 1, 2000)
      #
  buttons.append "button"
    .text "y=1000 z=1"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraYZTween(camera, 1000, 1)
        
  buttons.append "button"
    .text "top=59 bottom=53"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraTopBottomTween(camera, 59, 53)
        
  buttons.append "button"
    .text "top=900 bottom=-900"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraTopBottomTween(camera, 900, -900)
        
  buttons.append "button"
    .text "top=200 bottom=-150"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraTopBottomTween(camera, 200, -150)
        
  buttons.append "button"
    .text "center on z=850e6" # From above!
    .on "click", ->
      pad = 10e6/2
      band = 10e6/2
      mid = 850e6
      [ top, bottom ] = [ mid-band-pad, mid+band+pad ]
        .map dims.z.scale
        .map (d) -> d * -1 # Why? I'm not really sure.
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraTopBottomTween(camera, top, bottom)
        
  buttons.append "button"
    .text "fade not 850e6" #
    .on "click", ->
      pad = 10e6/2
      band = 10e6/2
      mid = 850e6
      [ low, high ] = [ mid-band-pad, mid+band+pad ]
        #.map dims.z.scale
        #.map (d) -> d * -1 # Why? I'm not really sure.
      #d3.transition()
        #.duration 2000
        #.tween "moveCamera", cameraTopBottomTween(camera, top, bottom)
  

  
  #   
  #
  # 
  ####################################################

      
  return { main, camera, scene, renderer }
  
cameraTopBottomTween = (camera, top, bottom) ->
  ->
    i = 
      top: d3.interpolate camera.top, top
      bottom: d3.interpolate camera.bottom, bottom
    return (t) ->
      for key, value of i
        camera[key] = value t
      camera.updateProjectionMatrix()

cameraYZTween = (camera, y, z) ->
  ->
    i = 
      y: d3.interpolate camera.position.y, y
      z: d3.interpolate camera.position.z, z
    return (t) ->
      camera.position.set camera.position.x, i.y(t), i.z(t)
  
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
  for key, value of obj
    value.scale = d3.scale.linear().domain([Infinity, -Infinity])
  obj.x.scale.domain [Date.now(), Date.now() + 1e3 * 20]
  return obj
  
getBufferGeometry = (pointsGeom) ->
  geom = new THREE.BufferGeometry()
  vertices = pointsGeom.vertices
  flattened = vertices
    .map (v) -> v.toArray()
    .reduce (a, b) -> a.concat b
    
  positions = flattened
  geom.addAttribute 'position', new THREE.Float32Attribute positions, 3
  
  colors = vertices
    .map (v) -> d3.range(3).map -> Math.random()
    .reduce (a, b) -> a.concat b
  geom.addAttribute 'color', new THREE.Float32Attribute colors, 3
  
  alphas = vertices.map -> 0
  geom.addAttribute 'mohawk', new THREE.Float32Attribute alphas, 1
  geom.addAttribute 'alpha', new THREE.Float32Attribute alphas, 1
  
  scales = vertices.map -> 1
  geom.addAttribute 'scale', new THREE.Float32Attribute scales, 1
  
  return geom
  
THREE.ShaderLib['donaldTrump'] = {

	uniforms: {
	  pointTexture: { type: "t", value: THREE.ImageUtils.loadTexture( "/spark1.png" ) }  
	},

	vertexShader: [
	  "attribute float whoaDude;"
	  "attribute float alpha;"
	  "attribute float mohawk;"
	  "attribute float scale;"
	  "varying float vAlpha;"
	  "varying vec3 vColor;"
		"void main() {",
		  "vColor = color;"
		  "vAlpha = alpha;"
		  "gl_PointSize = scale;"
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