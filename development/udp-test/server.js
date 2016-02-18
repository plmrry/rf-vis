
var osc = require("osc-min");
var dgram = require('dgram');
var server = dgram.createSocket('udp4');

var PORT = 33333;
var HOST = '0.0.0.0';

server.on('listening', function () {
    var address = server.address();
    console.log('UDP Server listening on ' + address.address + ":" + address.port);
});

server.bind(PORT, HOST);

server.on('message', function(d) {
  console.log(osc.fromBuffer(d));
})

// var message = {
//   address: "/carrier/freq",
//   args: [440.4]
// };
//
// var packet = osc.toBuffer(message);
//
// var client = dgram.createSocket('udp4');
//
// client.send(packet, 0, packet.length, PORT, HOST, function(err, bytes) {
//     if (err) throw err;
//     console.log('UDP message sent to ' + HOST +':'+ PORT);
//     client.close();
// });
