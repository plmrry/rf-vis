
# OSC Server
#
#

osc = require 'osc'
dgram = require 'dgram'
udpServer = dgram.createSocket 'udp4'

port = 33333

messages = 0

logMessages = -> console.log "Messages received: #{messages}"

udpServer.on 'message', (message, remote) ->
  messages++
  # console.log "Message from #{remote.address} : #{remote.port}"
  # try
  #   packet = osc.readPacket message, {}
  # catch error
  #   packet = message
  # console.log packet

udpServer.on 'listening', ->
  add = udpServer.address()
  console.log "UDP Server listening on #{add.address}, port #{add.port}"

udpServer.bind port

# HTTP Server
#
#

d3 = require 'd3'
# rapidQueue = require 'rapid-queue'

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

numToSend = 7e4
packets = []
# packets = rapidQueue.createQueue()

logPackets = -> console.log "Packets length: #{packets.length}"

connected.then (socket) ->
  console.log 'A user connected.'

  # setInterval ->
  #   socket.emit 'new packet', packets
  #   packets = []
  # , 5000

  udpServer.on 'message', (message) ->
    try
      packet = osc.readPacket message, {}
      packet.date = Date.now()
    catch error
      packet = message

    # packets.push packet
    socket.emit 'new packet', [packet]

    # if packets.length > numToSend
    #   p = packets.slice 0
    #   logPackets()
    #   socket.emit 'new packet', p
    #   packets = []

    # socket.emit 'new packet', packet



paulServe.listenWithCallback()
