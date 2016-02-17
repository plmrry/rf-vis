osc = require 'osc'
# dgram = require 'dgram'
#
# PORT = 33333
# HOST = '0.0.0.0'
#
# server = dgram.createSocket 'udp4'

# server.on 'listening', ->
#   address = server.address()
#   console.log('UDP Server listening on ' + address.address + ":" + address.port)
#
# server.on 'message', (message, remote) ->
#   # console.log(osc.readPacket(message, {}))
#
# server.bind(PORT, HOST)
#
# # packet = osc.writePacket
# #   address: "/amp"
# #   args: "-99.5234"
# #
# # console.log packet
#
# message = new Buffer('My KungFu is Good!')
#
# client = dgram.createSocket 'udp4'
# client.send message, 0, message.length, PORT, HOST, (err, bytes) ->
#   console.log 'UDP message sent to #{HOST}: #{PORT}'
#   client.close()
