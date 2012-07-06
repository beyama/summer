hooks = module.exports

Summer = require "./container"

hooks.initializingObject = ->
  Summer.addHook "afterPropertiesSet", (factory, instance, callback)->
    if typeof instance.afterPropertiesSet is "function"
      instance.afterPropertiesSet()
    callback()

hooks.applicationContextAware = ->
  Summer.addHook "afterInitialize", (factory, instance, callback)->
    if typeof instance.setApplicationContext is "function"
      scope = factory.scope
      context = if scope and scope isnt "prototype"
        if scope is "singleton"
          @root()
        else
          @context(scope)
      else
        @context
      instance.setApplicationContext(context)
    callback()

hooks.contextIdAware = ->
  Summer.addHook "afterInitialize", (factory, instance, callback)->
    if typeof instance.setContextId is "function"
      instance.setContextId(factory.id)
    callback()
