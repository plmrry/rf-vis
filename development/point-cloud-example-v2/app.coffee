setTimeout (-> do main), 0

scripts = [
  "cdnjs.cloudflare.com/ajax/libs/d3/3.5.6/d3.min.js"
  "cdnjs.cloudflare.com/ajax/libs/underscore.js/1.8.3/underscore-min.js"
  "cdnjs.cloudflare.com/ajax/libs/three.js/r72/three.min.js"
  "cdnjs.cloudflare.com/ajax/libs/stats.js/r14/Stats.min.js"
  "cdnjs.cloudflare.com/ajax/libs/immutable/3.7.5/immutable.min.js"
]
  .map fullUri
  .concat [ "node_modules/d3-timer/build/timer.min.js" ]

main = ->
  loadScripts(scripts)
    .then -> 
      initialize(window.d3)
      
initialize = (d3) ->
  debugger
    
# @return Promise
loadScripts = (scripts) ->
  head = getOrAppend(document) "head"
  elements = scripts.map (d) -> createWithAttrs("script") src: d
  loaded = Promise.all elements.map(getLoadPromise)
  elements.reduceRight ((a, b) -> a.concat [b]), []
    .map insertFirst(head)
    
  return loaded

# Side-effects
insertFirst = (parent) ->
  (element) ->
    firstChild = parent.firstChild
    if firstChild?
      parent.insertBefore element, firstChild
    else
      parent.appendChild element

# @return Element
createWithAttrs = (tagName) ->
  (attrs) ->
    element = document.createElement tagName
    element.setAttribute(key, value) for key, value of attrs
    return element
  
# @return Promise
getLoadPromise = (script) ->
  return new Promise (resolve) ->
    script.addEventListener 'load', resolve, false
    
selectOrAppend = (selection) ->
  (selector) ->
    s = selection.selectAll(selector).data(Array(1))
    s.enter().append(selector)
    return s
  
# @return Element
getOrAppend = (node) ->
  (tagName) ->
    element = node.getElementsByTagName(tagName)[0]
    if not element?
      element = document.createElement(tagName)
      node.appendChild element
    return element
    
fullUri = (uri) -> "https://#{uri}"