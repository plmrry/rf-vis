# coffeelint: disable=no_debugger
# coffeelint: disable=no_unnecessary_fat_arrows

setTimeout (-> do go), 0

NUM_POINTS = 5e5 # 4e5

random = d3.random.normal(0.5, 0.05)
#random = d3.random.bates(2)
#random = d3.random.irwinHall(2)

getNewDot = ->
  date: random()
  args: [ null, null, random(), random() ]
  
dispatch = d3.dispatch 'render'

stats = new Stats()
stats.setMode 0

stats.domElement.style.position = 'absolute';
stats.domElement.style.left = '0px';
stats.domElement.style.top = '0px';

go = ->
  container = d3.select('body').append('main')
  
  dots = new Dots()
  dots.initialize container
  
  #dispatch.on 'render.stats', ->
    #stats.begin()
    #stats.end()
    #stats.update()
  
  container.append () -> stats.domElement
  
  timer.timer (elapsed, time) ->
    newDots = d3.range 2000
      .map getNewDot
    newDot = {
      date: random()
      args: [ null, null, random(), random() ]
    }
    dots.newData newDots
    return false

class Dots
  data = []
  dotSize = 2

  dispatch.on 'render.draw', (threeState) ->
    threeState.renderer.render threeState.scene, threeState.camera

  accessors =
    date: (d) -> d.date
    hertz: (d) -> d.args[2]
    amp: (d) -> d.args[3]

  mapping =
    date: 'x'
    hertz: 'y'
    amp: 'z'

  # Utilities
  translate = (x, y) -> "translate(#{x},#{y})"
  degToRad = d3.scale.linear()
    .domain [0, 360]
    .range [0, 2 * Math.PI]

  initialize: (container) ->
    size = @getSizeFromWindow()

    @scales = @getNewScales size

    console.log @scales

    threeState = @initializeThree size
    container.append -> threeState.renderer.domElement
    @startRenderLoop threeState

    @addStuff threeState, size

  startRenderLoop: (threeState) ->
    render = ->
      requestAnimationFrame render
      stats.begin()
      dispatch.render threeState
      stats.end()
    render()

  initializeThree: (size) ->
    aspect = size.width / size.height

    camera = new THREE.PerspectiveCamera undefined, aspect, undefined, 1e4

    @mainObject = new THREE.Object3D()

    scene = new THREE.Scene()
    scene.add @mainObject

    renderer = new THREE.WebGLRenderer()

    renderer.setPixelRatio window.devicePixelRatio
    renderer.setSize size.width, size.height
    renderer.setClearColor "white"

    return {
      renderer: renderer
      scene: scene
      camera: camera
    }

  getSizeFromWindow: ->
    size =
      width: window.innerWidth
      height: window.innerHeight

    size.x = size.width
    size.y = size.height
    size.z = size.width * 0.7 # I dunno

    return size

  getNewScales: (size) ->
    scales = {
      x: d3.scale.linear().range [-size.x/2, size.x/2]
      y: d3.scale.linear().range [-size.y/2, size.y/2]
      z: d3.scale.linear().range [0, size.z]
    }

    return scales

  addStuff: (threeState, size) ->
    threeState.camera.position.z = 1200
    threeState.camera.position.y = -1500
    threeState.camera.lookAt new THREE.Vector3(0, 1000, 0)

    gridHelper = new THREE.GridHelper size.width/2, 100
    gridHelper.rotateX degToRad 90

    @mainObject.rotateZ degToRad -90

    dispatch.on 'render.rotate', =>
      # @mainObject.rotateX degToRad 0.5
      @mainObject.rotateZ degToRad 0.3
      # @mainObject.rotateY degToRad 0.5

    pointsGeom = new THREE.Geometry()
    pointsGeom.nextEmptyVertex = 0

    pointsMaterial = new THREE.PointsMaterial({ 
      color: 0x000000, 
      size: 50 
    })
    pointsMaterial.transparent = true
    pointsMaterial.opacity = 0.1

    p = NUM_POINTS

    d3.range(p).forEach (d) ->
      vertex = new THREE.Vector3()
      pointsGeom.vertices.push( vertex )

    @particles = new THREE.Points pointsGeom, pointsMaterial
    @mainObject.add @particles
    @mainObject.add gridHelper

    @mainObject.rotateZ degToRad -90


  newData: (newData) =>
    geometry = @particles.geometry
    next = geometry.nextEmptyVertex

    _.forEach newData, (d, i) =>
      v = geometry.vertices[i + next]
      if v?
        v.x = @scales.x accessors.date d
        v.y = @scales.y accessors.hertz d
        v.z = @scales.z accessors.amp d

    geometry.nextEmptyVertex += newData.length

    geometry.verticesNeedUpdate = true
