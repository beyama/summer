## coonamSummer
#
# **Summer** is a very simple straightforward IOC/DI container.
#
# See the [readme](http://github.com/beyama/coonam_mongo) for details of usage.
#
# The source for [coonamSummer is available](http://github.com/beyama/coonam_summer)
# on GitHub and released under the MIT license.

async = require "async"
EventEmitter = require("events").EventEmitter

# ### Ref class
#
# Is internally used to mark an argument/property as a reference to resolve.
# Instances of ref are returnd by Summer::ref.
class Ref
  constructor: (id)->
    return new Ref(id) unless @ instanceof Ref
    @id = id.toString()

  toString: -> @id

# ### Internal helper methods

# Create an instance of class with the supplied args as constructor arguments.
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

# Marker object to mark a scoped object as "in progress" during its asynchronous resolve.
InProgress = {}

# Internal helper to resolve references in argument lists.
resolveArguments = (context, args, callback)->
  if args?.length
    # resolve arguments in series
    async.mapSeries args, (arg, callback)=>
      if arg instanceof Ref
        context.resolve(arg.toString(), callback)
      else
        callback(null, arg)
    , callback
  else
    callback(null, args)

# Resolve and set properties from factory.properties.
resolveAndSetProperties = (context, factory, instance, callback)->
  properties = factory.properties
  hasProperties = if properties then Object.keys(properties).length else false

  if hasProperties
    async.forEachSeries Object.keys(properties), (propertyName, callback)->
      value = properties[propertyName]
      if value instanceof Summer.ref
        context.resolve value.toString(), (err, ref)->
          return callback(err) if err

          instance[propertyName] = ref
          callback()
      else
        instance[propertyName] = value
        callback()
    , (err)->
      return callback(err) if err
      Summer.runHooks("afterPropertiesSet", context, factory, instance, callback)
  else
    Summer.runHooks("afterPropertiesSet", context, factory, instance, callback)

# ## ResolveContext class
#
# Is used internally as binding for initializer functions to detect cyclical dependencies.
#
# It is a delegator to the current context so you can use it from inside your initializer like
# inside a context (e.g. @resolve, @get, @set, ...).
class ResolveContext
  constructor: (context)->
    @context = context
    @stack = []

  push: (id)-> @stack.push(id)

  pop: -> @stack.pop()

  contains: (id)-> @stack.indexOf(id) > -1

  resolve: (id, callback)-> @context.resolve(id, @, callback)

# ## The main class of Summer
class Summer extends EventEmitter
  @ref: Ref

  # Returns true if klass is a subclass of superklass otherwise false.
  @isSubclassOf: (klass, superKlass)->
      _super = klass.__super__
      while _super
        return true if _super is superKlass::
        _super = _super.__super__
      false

  # Get or set autowired properties.
  @autowire: (klass, properties)->
    return if typeof klass isnt "function"

    # setter
    if properties
      autowire = klass._autowire ||= {}
      # check if autowire is just inherited from parent
      if autowire is klass.__super__?.constructor._autowire
        # set new autowire object
        autowire = klass._autowire = {}

      autowire[k] = v for k, v of properties
      klass
    # getter
    else
      parent = if _super = klass.__super__?.constructor then @autowire(_super)

      if autowire = klass._autowire
        parent ||= {}
        parent[k] = v for k, v of autowire
        parent
      else
        parent

  @_hooks = {}

  # Register a hook for an event.
  @addHook: (event, hook)->
    hooks = @_hooks[event] ||= []
    hooks.push(hook)

  # Remove a hook from an event.
  @removeHook: (event, hook)->
    return unless (hooks = @_hooks[event])
    return if (index = hooks.indexOf(hook)) < 0

    hooks.splice(index, 1)

  # Remove all hooks for an event or all hooks if no event name is supplied.
  @removeAllHooks: (event)->
    if event
      delete @_hooks[event]
    else
      @_hooks = {}

  # Get an array of hooks for the specified event.
  @hooks: (event)-> @_hooks[event]

  # Run all hooks for an event.
  @runHooks: (event, context, factory, instance, callback)->
    return callback() unless @hooks(event)?.length

    async.forEachSeries @hooks(event), (hook, callback)->
      hook.call(context, factory, instance, callback)
    , callback

  # <h2 id="class_method_middleware">Middleware generator</h2>
  #
  # Returns a Connect middleware.
  #
  # The middleware will wrap the given parent context in a request context
  # on every request and assigning it to req.context.
  #
  # After calling res.end on the response object, shutdown will be called
  # on the request context container.
  @middleware: (parent, name="request")->
    (req, res, next)->
      context = new Summer(parent, name)
      req.context = context

      end = res.end

      res.end = ->
        context.shutdown()
        end.apply(res, arguments)

      next()

  # ### Constructor of Summer
  #
  # Takes optionally a parent context and a name.
  constructor: (parent, name)->
    super()
    @parent = parent if parent
    @name = name if name
    @attributes = {}
    @factories  = {}

  # Dispose an object by emitting "dispose", removing it from the context
  # and calling the "dispose" hooks.
  dispose: (id, callback)->
    object = @attributes[id]
    factory = @getFactory(id)

    if object
      # unregister object
      @delete(id)

      if factory
        # dispose object
        @emit("dispose", @, factory, object)
        Summer.runHooks("dispose", @, factory, object, callback)
      else
        callback()
    else
      callback()

  # Get the ids of all registered factories where class is klass or class is subclass of klass.
  getIdsForType: (klass)->
    set = {}
    for id, f of @factories when f.class and (f.class is klass or Summer.isSubclassOf(f.class, klass))
      set[id] = true
    set[id] = true for id in @parent.getIdsForType(klass) if @parent
    Object.keys(set)

  # Return a middleware with `this` as parent context.
  #
  # See: Summer.middleware
  middleware: (name="request")=>
    Summer.middleware(@, name)

  # Returns a reference to a factory to resolve.
  ref: Ref

  # Returns the root context.
  root: ->
    return @ unless @parent

    root = @
    while root = root.parent
      return root unless root.parent

  # Shutdown the context by emitting "shutdown" and disposing all resolved objects.
  shutdown: (callback)->
    callback ||= ->

    @emit "shutdown", @

    async.forEachSeries Object.keys(@attributes), (id, callback)=>
      @dispose(id, callback)
    , callback

  # Returns a named context.
  context: (name)->
    return @ if @name is name

    parent = @
    while parent = parent.parent
      return parent if parent.name is name
    undefined

  # Get a value from context.
  get: (key, lookupAncestors=true)->
    return @attributes[key] if @attributes.hasOwnProperty(key)
    return @parent.get(key) if lookupAncestors and @parent
    undefined

  # Set a value on context.
  set: (key, value)->
    @attributes[key] = value

  # Returns true if attribute is set otherwise false.
  has: (key, lookupAncestors=true)->
    return true if @attributes.hasOwnProperty(key)
    return @parent.has(key) if lookupAncestors and @parent
    false

  # Delete an attribute from `this` context.
  delete: (key)->
    delete @attributes[key]

  # Internally used to build an initializer function which constructs a class.
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

  # Internally used to wrap an initializer function to resolve arguments first,
  # then call the initializer and run the afterInitialize hooks.
  buildNcallInitializer: (factory)->
    args = factory.args
    func = factory.initializer

    (callback)->
      resolveArguments @, args, (err, args=[])=>
        return callback(err) if err

        args.push (err, result)=>
          return callback(err) if err

          Summer.runHooks "afterInitialize", @, factory, result, (err)=>
            return callback(err) if err

            resolveAndSetProperties @, factory, result, (err)->
              callback(err, result)
        func.apply(@, args)

  # Register a class/initializer
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
      factory.origInitializer = factory.initializer
      factory.initializer = @buildNcallInitializer(factory)

    @factories[id] = factory

  # Get factory by id.
  getFactory: (id)->
    return @factories[id] if @factories.hasOwnProperty(id)
    return @parent.getFactory(id) if @parent

  # Resolve one or more objects by id(s).
  resolve: (id, context, callback)->
    if typeof context is "function"
      callback = context
      context = new ResolveContext(@)

    # resolve a list of ids
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
    # resolve an alias to id map
    else if typeof id is "object"
      map = id
      result = {}

      async.forEachSeries Object.keys(map), (alias, callback)=>
        _id = map[alias]
        @resolve _id, (err, res)->
          callback(err) if err
          result[alias] = res
          callback()
      , (err)->
        return callback(err) if err
        callback(null, result)
    # resolve a single id
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
          value = scope.get(id, false)
          # retry if in progress
          if value is InProgress
            return async.nextTick resolve
          # return value if present
          else if value?
            return callback(null, value)
          else
            scope.set(id, InProgress)

        factory.initializer.call context, (err, result)->
          context.pop()
          if err
            scope.delete(id) if scope
            return callback(err)
          if scope
            scope.set(id, result)
            scope.emit "initialized", scope, factory, result
          callback(null, result)

      resolve()

# Create delegators from ResolveContext to Summer
for name, func of Summer.prototype when typeof func is "function"
  unless ResolveContext::[name]
    do (name, func)->
      ResolveContext::[name] = -> func.apply(@.context, arguments)

module.exports = Summer
