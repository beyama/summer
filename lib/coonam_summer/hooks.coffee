async = require "async"

Summer = require "./container"

exports = module.exports
hooks = exports.Hooks = {}

# Resolve and set properties from factory.properties.
#
# This hook will run the afterPropertiesSet hook after setting
# the resolved properties on the instance.
hooks.resolveAndSetProperties = (factory, instance, callback)->
  properties = factory.properties
  hasProperties = if properties then Object.keys(properties).length else false

  if hasProperties
    async.forEachSeries Object.keys(properties), (propertyName, callback)=>
      value = properties[propertyName]
      if value instanceof Summer.ref
        @resolve value.toString(), (err, ref)->
          return callback(err) if err

          instance[propertyName] = ref
          callback()
      else
        instance[propertyName] = value
        callback()
    , (err)->
      return callback(err) if err
      Summer.runHooks("afterPropertiesSet", @, factory, instance, callback)
  else
    Summer.runHooks("afterPropertiesSet", @, factory, instance, callback)

exports.resolveAndSetProperties = ->
  Summer.addHook "afterInitialize", hooks.resolveAndSetProperties

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
