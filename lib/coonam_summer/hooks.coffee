hooks = module.exports

Summer = require "./container"

hooks.initializingObject = ->
  Summer.addHook "afterPropertiesSet", (factory, instance, callback)->
    if typeof instance.afterPropertiesSet is "function"
      if instance.afterPropertiesSet.length
        instance.afterPropertiesSet(callback)
      else
        instance.afterPropertiesSet()
        callback()
    else
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
      if instance.setApplicationContext.length > 1
        instance.setApplicationContext(context, callback)
      else
        instance.setApplicationContext(context)
        callback()
    else
      callback()

hooks.contextIdAware = ->
  Summer.addHook "afterInitialize", (factory, instance, callback)->
    if typeof instance.setContextId is "function"
      if instance.setContextId.length > 1
        instance.setContextId(factory.id, callback)
      else
        instance.setContextId(factory.id)
        callback()
    else
      callback()

hooks.autowired = ->
  Summer.addHook "afterInitialize", (factory, instance, callback)->
    # get autowire from instance constructor
    autowire = Summer.autowire(instance.constructor)
    # or try the original initializer of the factory
    autowire ||= Summer.autowire(factory.origInitializer)

    return callback() unless autowire

    @resolve autowire, (err, autowire)->
      return callback(err) if err

      instance[k] = v for k, v of autowire
      callback()

