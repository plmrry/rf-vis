#
# OSC Server
#

osc = require 'osc-min'
dgram = require 'dgram'
udpServer = dgram.createSocket 'udp4'
_ = require 'highland'
fs = require 'fs'
d3 = require 'd3'

THROTTLE = 10
LOG_MESSAGES = true
WRITE_DATA = false
FAKE_DATA = false

port = 33333
address = '0.0.0.0'
udpServer.bind port, address

udpServer.on 'listening', ->
  add = udpServer.address()
  console.log "UDP Server listening on #{add.address}, port #{add.port}"
  
packets = _('message', udpServer)
  .map osc.fromBuffer
  .map (p) -> 
    p.date = Date.now()
    return p
  
#packets.resume()
  
raw = packets
  .filter (p) -> p.address is "/raw"
  .throttle THROTTLE
  .doto (p) -> logger p.date
  
raw.resume()
  
logger = (message) ->
  process.stdout.cursorTo(0);
  process.stdout.clearLine();
  process.stdout.write(message.toString());

#if LOG_MESSAGES
  #raw.done()
  #raw
    #.observe()
    #.doto (p) -> logger p.date 
    #.done()
    
if WRITE_DATA
  out = fs.createWriteStream "./data/data-#{Date.now()}"
  out.write "[\n"
  json = raw.observe().map (o) -> JSON.stringify(o) + ",\n"
  json.pipe out
  setTimeout (->
    json.pause()
    out.end "]", -> json.destroy()
  ), 20e3

#
# HTTP Server
#
#

express = require 'express'
app = express()
server = (require 'http').Server app
io = require('socket.io')(server)
portfinder = require 'portfinder'

io.on 'connection', (socket) ->
  console.log 'A user connected.'
  raw.fork()
    .each (p) ->
      socket.emit 'new packet', p
  
app.use '/', require './app'

new Promise (resolve) -> 
  portfinder.getPort (err, port) -> 
    resolve port
.then (port) ->
  return new Promise (resolve) ->
    server.listen port, resolve
.then ->
  a = server.address()
  console.log "HTTP Server listening at #{a.address}, port #{a.port}"
  
#randomFreq = d3.random.normal(1e8, 1e7)
#randomAmp = d3.random.normal(-110)
    #
#fakeDataInterval = setInterval (->
  #message = 
    #"address": "/raw"
    #"args": [
      #{"type":"double","value": Math.floor randomFreq() }
      #{"type":"float","value": randomAmp() }
    #]
    #"oscType":"message"
  #buff = osc.toBuffer message
  #udpServer.send buff, 0, buff.length, port, '127.0.0.1'
#), 1