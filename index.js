module.exports = process.env.SUMMER_COV ?
  require("./lib-cov/summer") :
  (require.extensions[".coffee"] ? require("./src/summer") : require("./lib/summer"))
