Summer = module.exports = require "./container"

for name, hook of require("./hooks")
  Summer[name] = hook

# register default hooks
Summer.initializingEntity()
Summer.disposableEntity()
Summer.applicationContextAware()
Summer.contextIdAware()
Summer.autowired()
