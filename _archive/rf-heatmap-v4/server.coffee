
#
# OSC Server
#
#
#
#

osc = require 'osc'
dgram = require 'dgram'
udpServer = dgram.createSocket 'udp4'

port = 33333
# address = '224.0.0.1'
address = '0.0.0.0'

udpServer.on 'listening', ->
  add = udpServer.address()
  console.log "UDP Server listening on #{add.address}, port #{add.port}"

udpServer.bind port, address

#
# HTTP Server
#
#
#
#

d3 = require 'd3'
EventEmitter = require 'events'

paulServe = require './paul-serve'
{
  app: app
  io: io
  express: express
  browserify: browserify
} = paulServe

app.use express.static("./static")
app.get "/heatmap", browserify("./heatmap/app.coffee")

queue = []

emitter = new EventEmitter()

emitter.on 'queueFlush', ->
  queue = []

startQueueFlushInterval = (time) ->
  setInterval ->
    emitter.emit 'queueFlush', queue
  , time

startQueueFlushInterval 50

udpServer.on 'message', (message) ->
  console.log Date.now()

udpServer.on 'message', (message) ->
  date = Date.now()
  packet = osc.readPacket message, {}
  packet.date = date
  queue.push packet

io.on 'connection', (socket) ->
  emitter.on 'queueFlush', (queue) ->
    d3.shuffle queue
    # socket.emit 'new packets', queue
    socket.emit 'new packets', queue.slice(0, 1000)

io.on 'connection', (socket) ->
  console.log 'A user connected.'

paulServe.listenWithCallback()
