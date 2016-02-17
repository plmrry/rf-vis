http = require 'http'
express = require 'express'
browserify = require 'browserify-middleware'
coffeeify = require 'coffeeify'
d3 = require 'd3'

app = express()
server = http.Server app
io = require('socket.io')(server)

browserify.settings 'extensions', ['.coffee']
browserify.settings 'transform', [coffeeify]
browserify.settings 'grep', /\.coffee$|\.js$/

app.use express.static("./static")

app.get "/heatmap", browserify("./heatmap/app.coffee")

io.on 'connection', (socket) ->
  console.log 'A user connected.'

  sendData = ->
    d3.range(50 * 50).map (d,i) ->
      setTimeout ->
        socket.emit('new packet', { value: Math.random() })
      , 10 * i

  setTimeout sendData, 1e3

server.listen(process.env.PORT || 8888, process.env.IP, ->
  a = server.address().address
  p = server.address().port
  console.log("Listening to the universe at #{a}, port #{p}")
)
