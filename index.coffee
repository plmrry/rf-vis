
# OSC Server
###############################################################################

osc = require 'osc-min'
dgram = require 'dgram'
udpServer = dgram.createSocket 'udp4'
_ = require 'highland'
fs = require 'fs'
d3 = require 'd3'
Rx = require 'rx'
RxAll = require ('rx/dist/rx.all')

port = 33333
address = '0.0.0.0'
udpServer.bind port, address

udpServer.on 'listening', ->
  add = udpServer.address()
  console.log "UDP Server listening on #{add.address}, port #{add.port}"

packets = Rx.Observable.fromEvent(udpServer, 'message')
  .sample 1
  .map (p) ->
    packet: p
    date: Date.now()
  .bufferWithCount 10
  .map (arr) ->
    arr.map (obj) ->
      out = osc.fromBuffer obj.packet
      out.date = obj.date
      return out

#packets
  #.sample 100
  #.subscribe (p) -> logger Date.now()

logger = (message) ->
  process.stdout.cursorTo(0)
  process.stdout.clearLine()
  process.stdout.write(message.toString())

# HTTP Server
##############################################################################

express = require 'express'
app = express()
server = (require 'http').Server app
io = require('socket.io')(server)
portfinder = require 'portfinder'

io.on 'connection', (socket) ->
  console.log 'A user connected.'
  packets.subscribe (p) -> socket.emit 'new packets', p

app.use '/', require './app'

new Promise (resolve) ->
  portfinder.getPort (err, port) -> resolve port
.then (port) ->
  new Promise (resolve) -> server.listen port, resolve
.then ->
  a = server.address()
  console.log "HTTP Server listening at #{a.address}, port #{a.port}"


      #.filter (p) -> p.address is "/raw"
  #.flatMap (arr) -> arr
  #.map osc.fromBuffer
  #.tap (p) -> p.date = Date.now()
  #.filter (p) -> p.address is "/raw"
