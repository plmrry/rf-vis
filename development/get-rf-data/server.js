// var osc = require("osc");
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

var message = {
  address: "/carrier/freq",
  args: [440.4]
};

// var packet = osc.writePacket(message);
var packet = osc.toBuffer(message);

var client = dgram.createSocket('udp4');

client.send(packet, 0, packet.length, PORT, HOST, function(err, bytes) {
    if (err) throw err;
    console.log('UDP message sent to ' + HOST +':'+ PORT);
    client.close();
});


// var last = Date.now();
// var max = 0;
//
//
// var _ = require("highland");
// _('message', server)
//   .throttle(10)
//   .map(function() {
//     return Date.now();
//   })
//   .doto(function(date) {
//     process.stdout.cursorTo(0);
//     process.stdout.clearLine();
//     process.stdout.write(date.toString());
//   })
//   .resume()

// server.on('message', function (message, remote) {
//     // console.log(Date.now());
//     // console.log('message from ' + remote.address + ':' + remote.port);
//     var packet;
//     try {
//       packet = osc.fromBuffer(message, {});
//     } catch (e) {
//       console.error(e);
//       console.log("Logging raw message instead.");
//       packet = message;
//     }
//     // console.log(packet);
//     var latency = Date.now() - last;
//     if (latency > max) max = latency;
//     process.stdout.clearLine();
//     process.stdout.cursorTo(0);
//     process.stdout.write(max.toString());
//     last = Date.now();
// });

// var collection = osc.collectMessageParts(message, {});

// console.log(collection.parts.reduce(function(a, b) { return a.concat(b); }));

// var joined = osc.joinParts(collection);
//
// console.dir(joined);
//
// eightBit = new Uint8Array(joined);
//
// console.log(eightBit);
