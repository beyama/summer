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

c = null

describe "hook", ->
  beforeEach ->
    Summer.removeAllHooks()
    c = new Summer
    c.register "test", class: Test
    c.register "testWithCallbacks", class: TestWithCallbacks, scope: "singleton"

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

  describe "applicationContextAware", ->
    beforeEach -> Summer.applicationContextAware()

    it "should call setApplicationContext on initialized object if implemented", (done)->
      c.resolve "test", (err, test)->
        should.not.exist err

        c.resolve "testWithCallbacks", (err, testWithCallbacks)->
          should.not.exist err

          testWithCallbacks.applicationContext.should.be.equal c
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
