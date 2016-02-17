# coffeelint: disable=no_debugger
# coffeelint: disable=no_unnecessary_fat_arrows

d3 = require 'd3'
THREE = require 'three/three.min'
_ = require 'underscore'

setTimeout (-> do go), 0

go = ->
  container = d3.select('body').append('main')
  dots = new Dots()
  dots.initialize container
  socket = io()
  socket.on 'new packets', dots.newData

class Dots

  data = []
  dotSize = 2
  dispatch = d3.dispatch 'render'

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
      dispatch.render threeState
    render()

  initializeThree: (size) ->
    aspect = size.width / size.height

    camera = new THREE.PerspectiveCamera undefined, aspect, undefined, 1e4

    @mainObject = new THREE.Object3D()

    scene = new THREE.Scene()
    scene.add @mainObject

    renderer = new THREE.WebGLRenderer()
    # renderer.sortObjects = false
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
        .domain [Date.now(), Date.now() + 1e3 * 20]
      y: d3.scale.linear().range [-size.y/2, size.y/2]
        .domain [88005859.375, 107980468.75]
      z: d3.scale.linear().range [0, size.z]
        .domain [-140.35134887695312, -60.616973876953125]
    }

    # for key, value of scales
    #   value.domain [Infinity, -Infinity]

    return scales

  addStuff: (threeState, size) ->
    threeState.camera.position.z = 1200
    threeState.camera.position.y = -2500
    threeState.camera.lookAt new THREE.Vector3(0, 1000, 0)

    gridHelper = new THREE.GridHelper size.width/2, 100
    gridHelper.rotateX degToRad 90

    @mainObject.rotateZ degToRad -90

    dispatch.on 'render.rotate', =>
      # @mainObject.rotateX degToRad 0.5
      @mainObject.rotateZ degToRad 0.1
      # @mainObject.rotateY degToRad 0.5

    pointsGeom = new THREE.Geometry()
    pointsGeom.nextEmptyVertex = 0

    pointsMaterial = new THREE.PointsMaterial({ color: 0x000000, size: 10 })
    pointsMaterial.transparent = true
    pointsMaterial.opacity = 0.05

    p = 1e6

    d3.range(p).forEach (d) ->
      vertex = new THREE.Vector3()
      pointsGeom.vertices.push( vertex )

    @particles = new THREE.Points pointsGeom, pointsMaterial

    @mainObject.add @particles

    @mainObject.add gridHelper

    @mainObject.rotateZ degToRad -90

  getExtents = (array) ->
    obj = {}
    for key, value of accessors
      obj[key] = d3.extent array, accessors[key]
    return obj

  maybeExpandDomains = (extents, scales, mapping) ->
    for type, extent of extents
      dimension = mapping[type]
      scale = scales[dimension]
      oldDomain = scale.domain()
      if (extent[0] < oldDomain[0]) and (extent[1] > oldDomain[1])
        scale.domain extent
      else if extent[0] < oldDomain[0]
        scale.domain [extent[0], oldDomain[1]]
      else if extent[1] > oldDomain[1]
        scale.domain [oldDomain[0], extent[1]]

  # geometry = new THREE.SphereGeometry 2
  #
  # material = new THREE.MeshBasicMaterial( {color: 0x454545} )
  # material.transparent = true
  # material.opacity = 0.5

  newData: (newData) =>
    # extents = getExtents newData
    # maybeExpandDomains extents, @scales, mapping

    geometry = @particles.geometry
    next = geometry.nextEmptyVertex
    # console.log next

    _.forEach newData, (d, i) =>
      v = geometry.vertices[i + next]
      if v?
        v.x = @scales.x accessors.date d
        v.y = @scales.y accessors.hertz d
        v.z = @scales.z accessors.amp d

    geometry.nextEmptyVertex += newData.length

    geometry.verticesNeedUpdate = true

    # sphere = new THREE.Mesh( geometry, material )
    #
    # sphere.position.x = @scales.x accessors.date d
    # sphere.position.y = @scales.y accessors.hertz d
    # sphere.position.z = @scales.z accessors.amp d
    #
    # @mainObject.add sphere
