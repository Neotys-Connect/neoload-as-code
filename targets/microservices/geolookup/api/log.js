class Log {
  static get DEBUG() { return 1; }
  static get INFO()  { return 2; }
  static get WARN()  { return 3; }
  static get FAIL()  { return 4; }

  static newInstance(log_level) { return new Log(log_level) }

  get level() {
    return this._level;
  }
  constructor(log_level) {
    this._level = this.parseLogLevel(log_level)
  }

  parseLogLevel(arg) {
    var inp = (arg?(arg+"").trim().toUpperCase():'')
    if(Log[inp] != undefined) return Log[inp];
    else return Log.FAIL; // default logging level
  }

  clog(msg) { console.log(msg) }

  debug(msg) { if(this.level<=Log.DEBUG) { this.clog(msg) }}
  info(msg) { if(this.level<=Log.INFO) { this.clog(msg) }}
  warn(msg) { if(this.level<=Log.WARN) { this.clog(msg) }}
  fail(msg) { if(this.level<=Log.FAIL) { this.clog(msg) }}
  always(msg) { this.clog(msg) }
}

module.exports = Log;
