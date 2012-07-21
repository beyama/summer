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

    c.register "testWithCallbacks",
      class: TestWithCallbacks
      scope: "singleton"
      init: "afterPropertiesSet"

    c.register "testWithAsyncCallbacks",
      class: TestWithAsyncCallbacks
      scope: "singleton"
      init: "afterPropertiesSet"

  describe "initializingEntity", ->
    beforeEach -> Summer.initializingEntity()

    it "should call method named in init option on the initialized entity", (done)->
      c.resolve "test", (err, test)->
        should.not.exist err

        c.resolve "testWithCallbacks", (err, testWithCallbacks)->
          should.not.exist err

          testWithCallbacks.afterPropertiesSetCalled.should.be.true
          done()

    it "should call method named in init option asynchronous on the initialized entity if implemented with callback argument", (done)->
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

    it "should autowire typed properties", (done)->
      class AbstractService
      class Service extends AbstractService

      c.register "service", class: Service

      class Baz
        Summer.autowire @, service: AbstractService

      c.register "baz", class: Baz

      c.resolve "baz", (err, baz)->
        should.not.exist err

        baz.service.should.instanceof Service
        done()

    it "should return an error if type of property is ambiguous", (done)->
      class AbstractService
      class Service1 extends AbstractService
      class Service2 extends AbstractService

      c.register "service1", class: Service1
      c.register "service2", class: Service2

      class Baz
        Summer.autowire @, service: AbstractService

      c.register "baz", class: Baz

      c.resolve "baz", (err, baz)->
        err.message.should.be.equal "The type `AbstractService` of autowired property `service` at `baz` is ambiguous."
        done()
