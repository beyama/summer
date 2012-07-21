async = require "async"

Summer = require "./container"

exports = module.exports
hooks = exports.Hooks = {}

# Call setApplicationContext with the context and an optional callback
# on the instance.
hooks.applicationContextAware = (factory, instance, callback)->
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

exports.applicationContextAware = ->
  Summer.addHook "afterInitialize", hooks.applicationContextAware

# Call setContextId with the entity id and an optional callback
# on the instance.
hooks.contextIdAware = (factory, instance, callback)->
  if typeof instance.setContextId is "function"
    if instance.setContextId.length > 1
      instance.setContextId(factory.id, callback)
    else
      instance.setContextId(factory.id)
      callback()
  else
    callback()

exports.contextIdAware = ->
  Summer.addHook "afterInitialize", hooks.contextIdAware

# Resolve and set autowired properties on instance.
hooks.autowired = (factory, instance, callback)->
  autowire = if factory.class
    # get autowired properties from class
    Summer.autowire(factory.class)
  else
    # get autowired properties from the original initializer
    Summer.autowire(factory.origInitializer)

  return callback() unless autowire
  
  # look for typed properties
  for alias, id of autowire
    if typeof id is "function"
      ids = @getIdsForType(id)

      if ids.length is 0
        return callback(new Error(
          "No factory found for type `#{id.name || 'unnamed'}` of autowired property `#{alias}` at `#{factory.id}`."
        ))
      else if ids.length > 1
        return callback(new Error(
          "The type `#{id.name || 'unnamed'}` of autowired property `#{alias}` at `#{factory.id}` is ambiguous."
        ))
      else
        autowire[alias] = ids[0]

  @resolve autowire, (err, autowire)->
    return callback(err) if err

    instance[k] = v for k, v of autowire
    callback()

exports.autowired = ->
  Summer.addHook "afterInitialize", hooks.autowired

call = (target, strOrFunc, callback)->
  if typeof strOrFunc is "string" and typeof target[strOrFunc] is "function"
    if target[strOrFunc].length
      target[strOrFunc](callback)
    else
      target[strOrFunc]()
      callback()
  else
    if strOrFunc.length > 1
      strOrFunc.call(@, target, callback)
    else
      strOrFunc.call(@, target)
      callback()

# Calls dispose function on instance.
hooks.disposableEntity = (factory, instance, callback)->
  if dispose = factory.dispose
    call.call(@, instance, dispose, callback)
  else
    callback()

exports.disposableEntity = ->
  Summer.addHook "dispose", hooks.disposableEntity

# Calls init function on instance.
hooks.initializingEntity = (factory, instance, callback)->
  if init = factory.init
    call.call(@, instance, init, callback)
  else
    callback()

exports.initializingEntity = ->
  Summer.addHook "afterPropertiesSet", hooks.initializingEntity
