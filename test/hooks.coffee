should = require "should"

Summer = require "../"

class Test
class TestWithCallbacks
  afterPropertiesSet: ->
    @afterPropertiesSetCalled = true

  setApplicationContext: (ctx)->
    @applicationContext = ctx

  setContextId: (id)->
    @contextId = id

class TestWithAsyncCallbacks
  afterPropertiesSet: (callback)->
    @afterPropertiesSetCalled = true
    callback()

  setApplicationContext: (ctx, callback)->
    @applicationContext = ctx
    callback()

  setContextId: (id, callback)->
    @contextId = id
    callback()

c = null

describe "hook", ->
  beforeEach ->
    Summer.removeAllHooks()
    c = new Summer
    c.register "test", class: Test
    c.register "testWithCallbacks", class: TestWithCallbacks, scope: "singleton"
    c.register "testWithAsyncCallbacks", class: TestWithAsyncCallbacks, scope: "singleton"

  describe "initializingObject", ->
    it "should call afterPropertiesSet on initialized object if implemented", (done)->
      # set hook
      Summer.initializingObject()

      c.resolve "test", (err, test)->
        should.not.exist err

        c.resolve "testWithCallbacks", (err, testWithCallbacks)->
          should.not.exist err

          testWithCallbacks.afterPropertiesSetCalled.should.be.true
          done()

    it "should call afterPropertiesSet async on initialized if implemented with callback argument", (done)->
      Summer.initializingObject()

      c.resolve "testWithAsyncCallbacks", (err, test)->
        should.not.exist err

        test.afterPropertiesSetCalled.should.be.true
        done()

  describe "applicationContextAware", ->
    beforeEach -> Summer.applicationContextAware()

    it "should call setApplicationContext on initialized if implemented", (done)->
      c.resolve "test", (err, test)->
        should.not.exist err

        c.resolve "testWithCallbacks", (err, testWithCallbacks)->
          should.not.exist err

          testWithCallbacks.applicationContext.should.be.equal c
          done()

    it "should call setApplicationContext async on initialized if implemented with callback argument", (done)->
      c.resolve "testWithAsyncCallbacks", (err, test)->
        should.not.exist err

        test.applicationContext.should.be.equal c
        done()

    it "should get application context with the right scope", (done)->
      child = new Summer(c, "request")

      c.register "test", class: TestWithCallbacks

      child.resolve "test", (err, test)->
        should.not.exist err

        test.applicationContext.should.be.equal child

        child.resolve "testWithCallbacks", (err, testWithCallbacks)->
          should.not.exist err

          testWithCallbacks.applicationContext.should.be.equal c
          done()

  describe "contextIdAware", ->
    beforeEach -> Summer.contextIdAware()

    it "should call setContextId on initialized object if implemented", (done)->
      c.resolve "test", (err, test)->
        should.not.exist err

        c.resolve "testWithCallbacks", (err, testWithCallbacks)->
          should.not.exist err

          testWithCallbacks.contextId.should.be.equal "testWithCallbacks"
          done()

    it "should call setContextId async on initialized if implemented with callback argument", (done)->
      c.resolve "testWithAsyncCallbacks", (err, test)->
        should.not.exist err

        test.contextId.should.be.equal "testWithAsyncCallbacks"
        done()

  describe "autowired", ->
    beforeEach -> Summer.autowired()

    it "should autowire dependencies of classes", (done)->
      c.register "foo", (c)-> c(null, "foo")
      c.register "bar", (c)-> c(null, "bar")

      class Baz
        Summer.autowire @, foo: "foo", bar: "bar"

      c.register "baz", class: Baz

      c.resolve "baz", (err, baz)->
        should.not.exist err

        baz.foo.should.be.equal "foo"
        baz.bar.should.be.equal "bar"
        done()

    it "should autowire dependencies of functions (initializer)", (done)->
      c.register "foo", (c)-> c(null, "foo")
      c.register "bar", (c)-> c(null, "bar")

      init = (c)-> c(null, {})
      Summer.autowire init, foo: "foo", bar: "bar"

      c.register "baz", init

      c.resolve "baz", (err, baz)->
        should.not.exist err

        baz.foo.should.be.equal "foo"
        baz.bar.should.be.equal "bar"
        done()
