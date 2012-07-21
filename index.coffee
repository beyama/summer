Summer = module.exports = require "./lib/coonam_summer/container"

for name, hook of require("./lib/coonam_summer/hooks")
  Summer[name] = hook

# register default hooks
Summer.initializingEntity()
Summer.disposableEntity()
Summer.applicationContextAware()
Summer.contextIdAware()
Summer.autowired()
