# coonamSummer

Summer is a very simple straightforward IOC/DI container. It was
developed with the goal in mind to define application
contexts and resolve multiple asynchronous resources 
with their dependencies with ease. 

* [Basic usage](./#section_basics)
  * [Root context](./#section_rootcontext)
  * [Scoped context](./#section_scopedcontext)
  * [Register initializer](./#section_register)
  * [Resolve objects](./#section_resolve)
* [Scoped locals](./#section_locals)
* [Scoped objects](./#section_scoped)
* [Middleware](./#section_middleware)
* [Contribute](./#section_contribute)
* [License](./#section_license)

<h2 id="section_basics">Basic usage</h2>

<h3 id="section_rootcontext">Root context</h3>

The root context, as its name implies, is a basic context without parent context.

**Initialize a root context:**

    Summer = require "coonamSummer"
    rootContext = new Summer

<h3 id="section_scopedcontext">Scoped context</h3>

A scoped context is an optionally named context with a parent context.

The scoped context is the place were [scoped locals](./#section_locals) 
and [scoped objects](./#section_scoped) are registered in 
(except "singleton" scoped objects, they are stored in the root context).

**Initialize a scoped context:**

    requestContext = new Summer(rootContext, "request")

**Get root context and scoped contexts:**

    childContext.parent #=> returns the parent context
    childContext.root() #=> returns the root context
    childContext.context("request") #=> returns the context with name `request`

<h3 id="section_register">Register initializer</h3>

There are three ways to register an initializer, either by register a 
class or an initializer function or an asynchronous node style function.

Summer::register can be called as follow:

    register(id, initializer_function)
    register(id, array_of_arguments, initializer_function)
    register(id, options, initializer_function)
    register(id, options)

**Possible options are:**

* initializer: The initializer function (can be supplied as second or third argument)
* finalizer: This function is called on deleting the resolved object from scope or
  by shutting down the scope (only useful for [scoped objects](./#section_scoped)).
* class: Class to initialize (only when no initializer is supplied)
* args: Arguments for initializer/constructor
* properties: Object with properties to set on initialized object

**Register a class:**

    c.register "fooService", class: FooSevice

**Register a class with constructor arguments:**

    c.register "fooService", class: FooSevice, args: [c.ref("db"), 5]

Summer::ref returns a reference to a registered service ("db" in this example).
This reference will be resolved and supplied as first constructor argument, 
the second constructor argument will be 5.

**Register a class with properties:**

    c.register "fooService",
      class: FooSevice
      properties:
        db: c.ref("db")
        maxConnections: 5

This properties will be applied after constructing the class. 
For an explanation of "c.ref" see the example above.

**Register an initializer function:**

    c.register "db", (callback)->
      db = new DB(...)
      db.open (err, db)->
        callback(err, db)

or

    c.register "db", 
      initializer: (callback)-> ...

**Register an initializer function with arguments:**

    c.register "usersCollection", [c.ref("db")], (db, callback)->
      db.collection "userCollection", (err, collection)->
        callback(err, collection)

or

    c.register "usersCollection", { args: c.ref("db") }, (db, callback)-> ...

or

    fs = require "fs"
    c.register "configFile", { args: __dirname + "/../config.json" }, fs.readFile

**Register an initializer function with multiple arguments:**

    c.register "userController", ["userCollection", "commentCollection"], (users, comments, callback)->
      callback(null, new UserController(users, comments))

**Register an initializer function with finalizer:**

    c.register "db",
      initializer: (callback)->
        db = new DB(...)
        db.open (err, db)->
          callback(err, db)
      finalizer: (db)->
        db.close()

<h3 id="section_resolve">Resolve objects</h3>

Summer can resolve one or more objects at once.

**Resolve one object:**

    c.resolve "serviceId", (err, service)-> ...

**Resolve multiple objects:**

    c.resolve ["serviceOne", "serviceTwo"], (err, services)->
      doSomething services.serviceOne
      doSomething services.serviceTwo

#### Manually resolve an object from an initializer

If you like to resolve an object manually from inside your initializer function,
it is important to do this with the method "resolve" on the current binding (this or @) 
and not with "resolve" on your context object, otherwise the cyclical dependency detection won't work.

<h2 id="section_locals">Scoped locals</h2>

The context/scope acts like an "inheritable" map where "get" and "has"
goes backwards up the ancestor chain of the scope to find a value. 
The methods "set" and "delete" will operate on the current scope and
shadow values from ancestor scopes.

**For example:**

    context.set "foo", "bar"
    childContext.has "foo" #=> true
    childContext.get "foo" #=> "bar"
    childContext.set "foo", "baz"
    childContext.get "foo" #=> "baz"
    context.get "foo" #=> "bar"
    childContext.delete "foo"
    childContext.get "foo" #=> "bar"

<h2 id="section_scoped">Scoped objects</h2>

Scoped objects are objects which are singletons in their scope.
The scope option can be any name of an existing named scope. Special scopes are
"prototype", which is not registered on any scope and "singleton", 
which is registered on the root context. If no scope option is given "prototype" is assumed.

**Singleton scope example:**

    c.register "fooService", class: FooSevice, scope: "singleton"

**Request scope example:**

    c.register "fooService", class: FooSevice, scope: "request"

<h2 id="section_middleware">Middleware</h2>

The Summer::middleware method returns a Connect middleware which wraps the context in
a request scope on every request. It calls shutdown on the request scope after calling
"res.end". It sets the newly created context on "req.context".

**For example:**

    app.use applicationContext.middleware([name="request"])
    app.use (req, res)->
      doSometing req.context
      res.end("ok") #=> will shutdown the previously created request context (req.context)

<h2 id="section_contribute">How to contribute</h2>

If you find what looks like a bug:

      Check the GitHub issue tracker to see if anyone else has reported an issue.
      If you don’t see anything, create an issue with information about how to reproduce it.

If you want to contribute an enhancement or a fix:

      Fork the project on github.
      Make your changes with tests.
      Commit the changes without making changes to any files that aren’t related to your enhancement or fix.
      Send a pull request.

<h2 id="section_license">License</h2>

Created by Alexander Jentz, Germany.

MIT License. See the included MIT-LICENSE file.
