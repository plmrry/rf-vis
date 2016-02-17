express = require 'express'
path = require 'path'
browserify = require 'browserify-middleware'
coffeeify = require 'coffeeify'

# See: gist.github.com/elentok/8400301
browserify.settings 'extensions', ['.coffee']
browserify.settings 'transform', [coffeeify]
browserify.settings 'grep', /\.coffee$/

module.exports = router = express.Router()

router.use express.static path.resolve __dirname, 'static'
router.use '/app', browserify path.resolve(__dirname, 'app.coffee')
router.use '/test', browserify path.resolve(__dirname, 'app.coffee')