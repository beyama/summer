async = require "async"
EventEmitter = require("events").EventEmitter

class Ref
  constructor: (id)->
    return new Ref(id) unless @ instanceof Ref
    @id = id.toString()

  toString: -> @id

# Is klass subclass of superklass
isSubclassOf = (klass, superKlass)->
    _super = klass.__super__
    while _super
      return true if _super is superKlass::
      _super = _super.__super__
    false

createInstance = (klass, args)->
  switch args?.length ? 0
    when 0 then new klass
    when 1 then new klass(args[0])
    when 2 then new klass(args[0], args[1])
    when 3 then new klass(args[0], args[1], args[2])
    when 4 then new klass(args[0], args[1], args[2], args[3])
    when 5 then new klass(args[0], args[1], args[2], args[3], args[4])
    when 6 then new klass(args[0], args[1], args[2], args[3], args[4], args[5])
    when 7 then new klass(args[0], args[1], args[2], args[3], args[4], args[5], args[6])
    when 8 then new klass(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])
    when 9 then new klass(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
    else throw new Error("Constructor must have a maximum arguments length of 9.")

inProcess = {} # marker

# resolve references in arguments list
resolveArguments = (context, args, callback)->
  if args?.length
    # resolve arguments
    async.mapSeries args, (arg, callback)=>
      if arg instanceof Ref
        context.resolve(arg.toString(), callback)
      else
        callback(null, arg)
    , callback
  else
    callback(null, args)

# resolve and set properties
resolveAndSetProperties = (context, factory, target, properties, callback)->
  async.forEachSeries Object.keys(properties), (propertyName, callback)=>
    value = properties[propertyName]
    if value instanceof Ref
      context.resolve value.toString(), (err, ref)->
        return callback(err) if err

        target[propertyName] = ref
        callback()
    else
      instance[propertyName] = value
      callback()
  , (err)->
    return callback(err) if err
    Container.runHooks("afterPropertiesSet", context, factory, target, callback)

class ResolveContext
  constructor: (container)->
    @container = container
    @stack = []

  push: (id)-> @stack.push(id)

  pop: -> @stack.pop()

  contains: (id)-> @stack.indexOf(id) > -1

  resolve: (id, callback)-> @container.resolve(id, @, callback)

class Container extends EventEmitter
  @ref: Ref

  @_hooks = {}

  @addHook: (event, hook)->
    hooks = @_hooks[event] ||= []
    hooks.push(hook)

  @removeHook: (event, hook)->
    return unless (hooks = @_hooks[event])
    return if (index = hooks.indexOf(hook)) < 0

    hooks.splice(index, 1)

  @hooks: (event)-> @_hooks[event]

  @runHooks: (event, context, factory, instance, callback)->
    return callback() unless @hooks(event)?.length

    async.forEachSeries @hooks(event), (hook, callback)->
      hook.call(context, instance, callback)
    , callback

  @middleware: (parent, name="request")->
    # middleware function
    (req, res, next)->
      context = new Container(parent, name)
      req.context = context

      end = res.end

      res.end = ->
        context.shutdown()
        end.apply(res, arguments)

      next()

  constructor: (parent, name)->
    super()
    @parent = parent if parent
    @name = name if name
    @attributes = {}
    @factories  = {}
    @resolved   = null
    @shutdownHooks = null

  registerShutdownHook: (id, hook)->
    @shutdownHooks ||= {}
    @shutdownHooks[id] = hook

  setResolvedObject: (id, object)->
    @resolved ||= {}
    @resolved[id] = object

  getResolvedObject: (id)->
    @resolved?[id]

  hasResolvedObject: (id)->
    @resolved?[id]?

  dispose: (id, callback)->
    return callback() unless @hasResolvedObject(id)

    object = @getResolvedObject(id)
    factory = @getFactory(id)

    @emit("dispose", @, factory, object)

    delete @resolved[id]

    if (hook = @shutdownHooks?[id])
      delete @shutdownHooks[id]
      hook.call @, object, ->
        Container.runHooks("dispose", @, factory, object, callback)
    else
      Container.runHooks("dispose", @, factory, object, callback)

  getIdsForType: (klass)->
    for id, f of @factories when f.class and (f.class is klass or isSubclassOf(f.class, klass))
      id

  middleware: (name="request")->
    Container.middleware(@, name)

  ref: Ref

  root: ->
    return @ unless @parent

    root = @
    while root = root.parent
      return root unless root.parent

  shutdown: (callback)->
    callback ||= ->

    @emit "shutdown", @
    return callback() unless @resolved

    async.forEachSeries Object.keys(@resolved), (id, callback)=>
      @dispose(id, callback)
    , callback

  context: (name)->
    return @ if @name is name

    parent = @
    while parent = parent.parent
      return parent if parent.name is name
    undefined

  get: (key)->
    return @attributes[key] if @attributes.hasOwnProperty(key)
    return @parent.get(key) if @parent
    undefined

  set: (key, value)->
    @attributes[key] = value

  has: (key)->
    return true if @attributes.hasOwnProperty(key)
    return @parent.has(key) if @parent
    false

  delete: (key)->
    delete @attributes[key]

  buildClassInitializer: (factory)->
    # wrap constructor
    factory.initializer = (args...)->
      callback = args.pop()
      try
        instance = createInstance(factory.class, args)
      catch error
        return callback(error)
      callback(null, instance)
    @buildNcallInitializer(factory)

  buildNcallInitializer: (factory)->
    args = factory.args
    func = factory.initializer
    properties = factory.properties
    hasProperties = properties? and Object.keys(properties).length

    (callback)->
      resolveArguments @, args, (err, args=[])=>
        return callback(err) if err

        args.push (err, result)=>
          return callback(err) if err

          Container.runHooks "afterInitialize", @, factory, result, (err)=>
            return callback(err) if err

            if hasProperties
              resolveAndSetProperties @, factory, result, properties, (err)->
                callback(null, result)
            else
              callback(null, result)
        func.apply(@, args)

  register: (id, options, func)->
    factory = { id: id, initializer: func }

    if typeof options is "function"
      factory.initializer = options
    else if Array.isArray(options)
      factory.args = options
    else
      factory[k] = v for k, v of options

    if typeof (factory.initializer or factory.class) isnt "function"
      throw new Error("Either initializer or class must must be supplied.")

    if (factory.initializer and factory.class)
      throw new Error("Either class or initializer can be supplied (but not both).")

    if factory.args? and not Array.isArray(factory.args)
      factory.args = [factory.args]

    if factory.class
      factory.initializer = @buildClassInitializer(factory)
    else
      factory.initializer = @buildNcallInitializer(factory)

    @factories[id] = factory

  getFactory: (id)->
    return @factories[id] if @factories.hasOwnProperty(id)
    return @parent.getFactory(id) if @parent

  resolve: (id, context, callback)->
    if typeof context is "function"
      callback = context
      context = new ResolveContext(@)

    if Array.isArray(id)
      ids = id
      result = {}

      async.forEachSeries ids, (id, callback)=>
        @resolve id, context, (err, res)->
          return callback(err) if err

          result[id] = res
          callback(null, res)
      , (err)->
        return callback(err) if err
        callback(null, result)
    else
      factory = @getFactory(id)

      unless factory
        return callback(new Error("No factory found with id `#{id}`."))

      if context.contains(id)
        return callback(new Error("A cyclical dependency was detected."))

      context.push(id)

      # get context for scope
      if factory.scope and factory.scope isnt "prototype"
        scope = if factory.scope is "singleton" then @root() else @context(factory.scope)
        unless scope
          return callback(new Error("Scope `#{factory.scope}` not found."))

      resolve = =>
        if scope
          value = scope.getResolvedObject(id)
          # retry if in process
          if value is inProcess
            return async.nextTick resolve
          # return value if present
          else if value?
            return callback(null, value)
          else
            scope.setResolvedObject(id, inProcess)

        factory.initializer.call context, (err, result)->
          context.pop()
          if err
            scope.delete(id) if scope
            return callback(err)
          if scope
            scope.registerShutdownHook(id, factory.finalizer) if factory.finalizer
            scope.setResolvedObject(id, result)
            scope.emit "initialized", scope, id, result
          callback(null, result)

      resolve()

# create delegators from ResolveContext to Container
for name, func of Container.prototype when typeof func is "function"
  unless ResolveContext::[name]
    do (name, func)->
      ResolveContext::[name] = -> func.apply(@.container, arguments)

Container.ref = Ref
module.exports = Container
