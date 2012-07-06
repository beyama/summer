should = require "should"

connect = require "connect"
request = require "supertest"
fs = require "fs"

Summer = require "../"
ref = Summer.ref

c = null

class Test
  constructor: (args...)->
    @args = args

describe "Summer", ->
  beforeEach ->
    Summer.removeAllHooks()
    c = new Summer

  describe "class method .addHook", ->
    it "should register hook for an event", ->
      hook = (factory, instance, callback)->
      Summer.addHook "afterPropertiesSet", hook
      Summer.hooks("afterPropertiesSet").should.include hook

  describe "class method .removeHook", ->
    it "should remove hook from an event", ->
      hook = (factory, instance, callback)->
      Summer.addHook "afterPropertiesSet", hook
      Summer.removeHook "afterPropertiesSet", hook
      Summer.hooks("afterPropertiesSet").should.not.include hook

  describe "class method .removeAllHooks", ->
    it "should remove all hooks for an event", ->
      Summer.addHook "afterPropertiesSet", (factory, instance, callback)->
      Summer.removeAllHooks "afterPropertiesSet"
      should.not.exist Summer.hooks("afterPropertiesSet")

    it "should remove all hooks if no event is given", ->
      Summer.addHook "afterPropertiesSet", (factory, instance, callback)->
      Summer.addHook "afterInitialize", (factory, instance, callback)->
      Summer.removeAllHooks()

      should.not.exist Summer.hooks("afterPropertiesSet")
      should.not.exist Summer.hooks("afterInitialize")

  describe "class method .runHooks", ->
    it "should run registerd hooks", (done)->
      instance = null

      Summer.addHook "anEvent", (factory, object, callback)->
        instance = object
        factory.id.should.be.equal "foo"
        @.should.be.equal c
        callback()

      c.register "foo", class: Test

      c.resolve "foo", (err, foo)->
        should.not.exist err

        factory = c.getFactory("foo")
        Summer.runHooks "anEvent", c, factory, foo, (err)->
          should.not.exist err
          foo.should.be.equal instance
          done()

  describe ".get", ->
    it "should return undefined if no value is set", ->
      should.ok c.get("foo") is undefined

    it "should return value", ->
      c.set("foo", "bar")
      c.get("foo").should.be.equal "bar"

    it "should return value from parent", ->
      child = new Summer(c)
      c.set("foo", "bar")
      child.get("foo").should.be.equal "bar"

  describe ".set", ->
    it "should set attributes of container", ->
      c.set("foo", "bar")
      c.attributes.should.have.property "foo", "bar"

    it "should shadow parent properties", ->
      c.set("foo", "bar")
      child = new Summer(c)
      child.set("foo", "baz")
      child.attributes.should.have.property "foo", "baz"
      c.attributes.should.have.property "foo", "bar"

  describe ".has", ->
    it "should return false if no value is set", ->
      c.has("foo").should.be.false

    it "should return true if value is set", ->
      c.set("foo", "bar")
      c.has("foo").should.be.true

    it "should return value if value is set on parent", ->
      child = new Summer(c)
      c.set("foo", "bar")
      child.has("foo").should.be.true

  describe ".register", ->
    it "should throw an error if called with both initializer and class", ->
      (-> c.register "object", class: Test, initializer: (->)).should.throw()

    it "should throw an error if class is not a function", ->
      (-> c.register "object", class: 42).should.throw()

    it "should register factory", ->
      fn = (callback)->
        callback(null, {})

      c.register "object", fn

      factory = c.getFactory("object")

      factory.id.should.be.equal "object"
      should.exist factory.initializer
      should.not.exist factory.requires

    it "should register factory with dependencies", ->
      fn = (callback)->
        callback(null, {})

      c.register "object", ["otherObject"], fn

      factory = c.getFactory("object")

      factory.id.should.be.equal "object"
      factory.args.should.have.length 1
      factory.args.should.include "otherObject"

    it "should build factory for class", (done)->
      c.register "test", class: Test

      factory = c.getFactory("test")
      factory.id.should.be.equal "test"
      factory.class.should.be.equal Test
      should.exist factory.initializer

      c.resolve "test", (err, test)->
        should.not.exist err
        test.should.be.instanceof Test
        done()

  describe ".resolve", ->
    it "should find and call factory", (done)->
      called = false

      c.register "object", (callback)->
        called = true
        @.context.should.be.equal c
        callback(null, "foo")

      c.resolve "object", (err, object)->
        should.not.exist err

        called.should.be.true
        object.should.be.equal "foo"
        done()

    it "should find and call factory with resolved dependencies", (done)->
      called = false
      object = { foo: "bar" }

      c.register "object", (callback)->
        callback(null, object)

      c.register "foo", [ref("object")], (object, callback)->
        called = true
        callback(null, object.foo)

      c.resolve "foo", (err, result)->
        should.not.exist err

        called.should.be.true
        result.should.be.equal "bar"
        done()

    it "should detect cyclical dependencies", (done)->
      c.register "one", [ref("one")], (callback)->
        callback(null, 1)

      c.resolve "one", (err, result)->
        err.message.should.be.equal "A cyclical dependency was detected."
        done()

    it "should return an error if factory not found by supplied id", (done)->
      c.resolve "bang", (err, result)->
        err.message.should.be.equal "No factory found with id `bang`."
        done()

    it "should resolve multiple objects at once", (done)->
      c.register "one", (callback)->
        callback(null, 1)

      c.register "two", (callback)->
        callback(null, 2)

      c.register "three", (callback)->
        callback(null, 3)

      c.resolve ["one", "two", "three"], (err, result)->
        should.not.exist err

        result.one.should.be.equal 1
        result.two.should.be.equal 2
        result.three.should.be.equal 3
        done()

    it "should set resolved object on root context if scope is singleton", (done)->
      child = new Summer(c)
      c.register "test", class: Test, scope: "singleton"

      child.resolve "test", (err, test)->
        should.not.exist err

        child.has("test", false).should.be.false
        c.get("test").should.be.equal test
        done()

    it "should get resolved object from context if already resolved", (done)->
      child = new Summer(c)
      c.register "test", class: Test, scope: "singleton"

      child.resolve "test", (err, test)->
        should.not.exist err
        child.resolve "test", (err, test2)->
          should.not.exist err
          test2.should.be.equal test
          done()

    it "should wait for resolves in process", (done)->
      called = false
      count  = 0
      c.register "test", scope: "singleton", (callback)->
        process.nextTick ->
          called.should.be.false
          called = true
          callback(null, "foo")

      for i in [0..2]
        process.nextTick ->
          c.resolve "test", (err, result)->
            should.not.exist err
            result.should.be.equal c.get("test")
            if ++count is 3
              done()

    it "should set resolved object on named context if scope isnt singleton or prototype", (done)->
      req = new Summer(c, "request")
      c.register "test", class: Test, scope: "request"
      
      req.resolve "test", (err, test)->
        should.not.exist err
        test.should.be.equal req.get("test")
        c.has("test").should.be.false
        done()

    it "should emit 'initialized'", (done)->
      called = false

      c.register "test", class: Test, scope: "singleton"

      c.on "initialized", (ctx, factory, object)->
        called = true
        factory.id.should.be.equal "test"
        object.should.be.instanceof Test

      c.resolve "test", (err, test)->
        should.not.exist err

        called.should.be.true
        done()

    it "should get an error if named context is not found", (done)->
      c.register "test", class: Test, scope: "request"
      
      c.resolve "test", (err, test)->
        err.message.should.be.equal "Scope `request` not found."
        done()

    it "should use a function with node style callback as initializer", (done)->
      c.register "file", { args: __dirname + "/container.coffee" }, fs.readFile

      c.resolve "file", (err, data)->
        should.not.exist err

        /should use a function/.test(data).should.be.true
        done()

    it "should resolve class with constructor arguments", (done)->
      c.register "test1", class: Test, args: ["foo"]
      c.register "test2", class: Test, args: [ref("test1")]

      c.resolve "test2", (err, test2)->
        should.not.exist err

        test2.should.be.instanceof Test
        test2.args.should.have.length 1

        test1 = test2.args[0]
        test1.should.be.instanceof Test
        test1.args.should.have.length 1
        test1.args[0].should.be.equal "foo"
        done()

    it "should resolve class properties", (done)->
      c.register "test1", class: Test, args: ["foo"]
      c.register "test2", class: Test, properties: { test: ref("test1") }

      c.resolve "test2", (err, test2)->
        should.not.exist err

        test2.should.be.instanceof Test
        test2.args.should.have.length 0

        test1 = test2.test
        test1.should.be.instanceof Test
        test1.args.should.have.length 1
        test1.args[0].should.be.equal "foo"
        done()

  describe ".dispose", ->
    it "should run finalizer, delete resolved object and emit 'dispose'", (done)->
      finalizerCalled = false
      listenerCalled  = false

      c.register "test",
        class: Test
        scope: "singleton"
        finalizer: (object, callback)->
          finalizerCalled = true
          object.should.be.instanceof Test
          @.should.be.equal c
          callback()

      c.on "dispose", (ctx, id, object)->
        listenerCalled = true
        ctx.should.be.equal c
        object.should.be.instanceof Test

      c.resolve "test", (err, test)->
        should.not.exist err

        c.dispose "test", ->
          finalizerCalled.should.be.true
          listenerCalled.should.be.true
          c.has("test").should.be.false
          done()

  describe ".getIdsForType", ->
    it "should get ids for all factories with class or subclass of class", ->
      class Test2 extends Test
      class Other

      c.register "test", class: Test
      c.register "test1", class: Test
      c.register "test2", class: Test2
      c.register "other", class: Other

      ids = c.getIdsForType(Test)
      ids.should.have.length 3
      ids.should.include "test"
      ids.should.include "test1"
      ids.should.include "test2"

      ids = c.getIdsForType(Test2)
      ids.should.have.length 1
      ids.should.include "test2"

  describe ".shutdown", ->
    it "should delete all resolved objects", (done)->
      c.register "test", class: Test, scope: "singleton"

      c.resolve "test", (err, test)->
        should.not.exist err

        c.shutdown ->
          c.has("test").should.be.false
          done()

  app = context = null

  describe ".middleware", ->
    beforeEach ->
      app = connect()
      app.use c.middleware()

    it "should set req.context", (done)->
      app.use (req, res)->
        context = req.context
        context.should.be.instanceof Summer
        context.parent.should.be.equal c
        res.end("ok")

      request(app)
        .get("/")
        .expect("ok", done)

    it "should shutdown context if res.end called", (done)->
      called = false

      app.use (req, res)->
        req.context.resolve "test", (err, test)->
          should.not.exist err
          res.end("ok")

      c.register "test",
        class: Test
        scope: "request"
        finalizer: (object, callback)->
          called = true
          callback()

      request(app)
        .get("/")
        .expect "ok", ->
          called.should.be.true
          done()
