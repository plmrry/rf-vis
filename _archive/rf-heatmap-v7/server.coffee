
# OSC Server
###############################################################################

osc = require 'osc-min'
dgram = require 'dgram'
udpServer = dgram.createSocket 'udp4'
_ = require 'highland'
fs = require 'fs'
d3 = require 'd3'

THROTTLE = 1

port = 33333
address = '0.0.0.0'
udpServer.bind port, address

udpServer.on 'listening', ->
  add = udpServer.address()
  console.log "UDP Server listening on #{add.address}, port #{add.port}"

packets = _('message', udpServer)
  #.batchWithTimeOrCount 100, 1000
  #.filter () -> Math.random() < 0.1
  .throttle THROTTLE
  #.ratelimit 1000, 5
  #.filter -> Math.random() < 0.10
  .map osc.fromBuffer
  .filter (p) -> p.address is "/raw"
  .tap (p) -> p.date = Date.now()
  .tap (p) -> logger p.date

logger = (message) ->
  process.stdout.cursorTo(0)
  process.stdout.clearLine()
  process.stdout.write(message.toString());

# HTTP Server
##############################################################################

express = require 'express'
app = express()
server = (require 'http').Server app
io = require('socket.io')(server)
portfinder = require 'portfinder'

io.on 'connection', (socket) ->
  console.log 'A user connected.'
  packets.fork()
    .each (p) -> socket.emit 'new packets', [p]
  
app.use '/', require './app'

new Promise (resolve) -> 
  portfinder.getPort (err, port) -> resolve port
.then (port) ->
  new Promise (resolve) -> server.listen port, resolve
.then ->
  a = server.address()
  console.log "HTTP Server listening at #{a.address}, port #{a.port}"
