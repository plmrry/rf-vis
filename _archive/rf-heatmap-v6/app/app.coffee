d3 = require 'd3'
THREE = require 'three/three.min'
_ = require 'highland'

ROTATE_SPEED = 0
POINT_OPACITY = 0.2
POINT_SIZE = 15
MAX_POINTS = 10e3
LOOKAT_OFFSET = 0

setTimeout (-> do initialize), 0

initialize = () ->
  console.log "Hello mamma."
  
  { main, camera, scene, renderer } = do addStuff
  
  counter = main.append("div")
    .style 
      position: 'absolute', top: 0, left: 0, 
      width: '10rem', 'text-align': 'right'
  
  dims = getDimensions()
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
    #.doto updateHelpers scene
    .doto setRange dims
    .done()
    
  i = 0
  
  unscaledValues = _ 'new packet', socket
    .map setPacketUnscaledValues dims
    
  expand =
    #x: {}
    y: scale: dims.y.scale
    z: scale: dims.z.scale
    
  latestDate = 0
  
  unscaledValues
    .observe()
    .map (p) -> p.date
    .each (d) -> latestDate = d
    
  once = true
    
  unscaledValues
    .doto (p) -> 
      if once
        dims.x.scale.domain [ p.date, p.date + 20 * 1e3 ]
        once = false
    .map maybeExpandDomains expand
    .filter (d) -> d is true
    #.doto -> 
      #console.log "domains expanded"
      #for key, value of dims
        #console.log key, value.scale.domain()
    #.doto scaleAllGeometry particles, dims
    .done()
    
  unscaledValues.fork()
    #.map scalePointByMutation dims
    #.doto updateGeometry particles
    .doto scalePointByMutation dims
    .map addPoint particles
    .doto setUpdateFlag particles
    #.doto scaleAllGeometry particles, dims
    .done()
    
  unscaledValues.fork().map -> 1
    .scan 0, _.add
    .each (d) -> counter.text d
    
  # Each animation frame
  _(frameGenerator).each ->
    mainObj.rotateY degToRad ROTATE_SPEED
    latestX = dims.x.scale latestDate
    
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
      
scaleAllGeometry = (particles, dims) ->
  (point) ->
    geometry = particles.geometry
    next = geometry.nextEmptyVertex
    _(geometry.vertices).take(next)
      .filter (v) -> v.unscaled?
      .each (v) ->
        scalePointByMutation(dims) v
    geometry.verticesNeedUpdate = true
      
addPoint = (particles) ->
  (point) ->
    geometry = particles.geometry
    vertices = geometry.vertices
    
    n = geometry.nextEmptyVertex
    numVerts = vertices.length
    if n >= numVerts
      geometry.nextEmptyVertex = 0
    next = geometry.nextEmptyVertex
    
    v = geometry.vertices[next] || geometry.vertices
    v.copy point
    v.unscaled = point.unscaled
    geometry.nextEmptyVertex++
    #geometry.verticesNeedUpdate = true
    #return v
    
updateGeometry = (particles) ->
  (point) ->
    geometry = particles.geometry
    next = geometry.nextEmptyVertex
    geometry.vertices[next].copy point
    geometry.nextEmptyVertex++
    #geometry.verticesNeedUpdate = true
    
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
  pointsMaterial = new THREE.PointsMaterial
    color: 0x000000, size: POINT_SIZE, 
    depthWrite: false
  pointsMaterial.transparent = true
  pointsMaterial.opacity = POINT_OPACITY
  pointsGeom.vertices = d3.range(maxPoints).map () -> 
    p = new THREE.Vector3()
    p.visible = false
    return p
  particles = new THREE.Points pointsGeom, pointsMaterial
  return particles
  
addStuff = ->
  axisHelper = new THREE.AxisHelper 100 
  axisHelper.name = "axis"
  
  mainObject = new THREE.Object3D()
  mainObject.name = 'main'
  #mainObject.add axisHelper
  
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
    .text "transition to y=1 z=2000"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraZYTween(camera, 2000, 1)
      
  buttons.append "button"
    .text "transition to z=1 y=1000"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraZYTween(camera, 10, 1000)
        
  buttons.append "button"
    .text "transition to top=59 bottom=53"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraTopBottomTween(camera, 59, 53)
        
  buttons.append "button"
    .text "transition to top=900 bottom=-900"
    .on "click", ->
      d3.transition()
        .duration 2000
        .tween "moveCamera", cameraTopBottomTween(camera, 900, -900)

  
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

cameraZYTween = (camera, z, y) ->
  ->
    i = 
      z: d3.interpolate camera.position.z, z
      y: d3.interpolate camera.position.y, y
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
  
  
  
#scalePoint = (dims) ->
  #(point) ->
    #scaled = new THREE.Vector3()
    #for dim, obj of dims
      #scaled[dim] = obj.scale point[dim]
    #return scaled
    
  
  #once = true
  #packets.fork()
    #.doto (p) -> 
      #if once then console.log p
      #once = false
    #.done()
    
    
    
#getPoint = (dimensions) ->
  #(packet) ->
    #point = new THREE.Vector3()
    #for dim, obj of dimensions
      #point[dim] = obj.accessor packet
    #return point
    
    
#camera.up.copy new THREE.Vector3 0, 0, -1