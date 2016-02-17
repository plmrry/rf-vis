
#
# OSC Server
#
#

osc = require 'osc'
dgram = require 'dgram'
udpServer = dgram.createSocket 'udp4'

port = 33333

udpServer.on 'listening', ->
  add = udpServer.address()
  console.log "UDP Server listening on #{add.address}, port #{add.port}"

udpServer.bind port

#
# HTTP Server
#
#

d3 = require 'd3'

paulServe = require './paul-serve'
{
  app: app
  io: io
  express: express
  browserify: browserify
} = paulServe

app.use express.static("./static")
app.get "/heatmap", browserify("./heatmap/app.coffee")

connected = new Promise (resolve) ->
  io.on 'connection', resolve

connected.then (socket) ->
  console.log 'A user connected.'

  udpServer.on 'message', (message) ->
    date = Date.now()
    packet = osc.readPacket message, {}
    packet.date = date
    console.log "hello"
  # setInterval ->
  #   point = queue.shift()
  #   if point?
  #     socket.emit 'new packet', packet
  # , 0
    socket.emit 'new packet', packet

paulServe.listenWithCallback()
