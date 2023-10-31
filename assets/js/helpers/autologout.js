// milisecond * seconds * minute
export const COUNTDOWN_MIN = 2;
const WARN_MIN = 18;
const LOGOUT_MIN = WARN_MIN + COUNTDOWN_MIN; // 20 mins
const WARN_TIME = 1000 * 60 * WARN_MIN;
const LOGOUT_TIME = 1000 * 60 * LOGOUT_MIN;

export default class AutoLogout {
  constructor(
    _warnCallback = () => {},
    _logoutCallback = () => {},
    _clearCallback = () => {}
  ) {
    this.events = [
      "load",
      "mousemove",
      "mousedown",
      "click",
      "scroll",
      "keypress",
    ];

    this.warn = this.warn.bind(this);
    this.logout = this.logout.bind(this);
    this.resetTimeout = this.resetTimeout.bind(this);
    this.warnCallback = _warnCallback;
    this.logoutCallback = _logoutCallback;
    this.clearCallback = _clearCallback;

    this.events.forEach((event) => {
      window.addEventListener(event, this.resetTimeout);
    });

    window.__boilerplate_autologout_warn = _warnCallback;

    this.setTimeout();
  }

  clearTimeout() {
    if (this.warnTimeout) clearTimeout(this.warnTimeout);

    if (this.logoutTimeout) clearTimeout(this.logoutTimeout);

    this.clearCallback();
  }

  setTimeout() {
    this.warnTimeout = setTimeout(this.warn, WARN_TIME);

    this.logoutTimeout = setTimeout(this.logout, LOGOUT_TIME);
  }

  resetTimeout() {
    this.clearTimeout();
    this.setTimeout();
  }

  warn() {
    console.log(
      `You will be logged out automatically in ${COUNTDOWN_MIN} minute.`
    );
    this.warnCallback();
  }

  logout() {
    // Send a logout request to the API
    this.destroy(); // Cleanup
    this.logoutCallback();
  }

  destroy() {
    this.clearTimeout();

    this.events.forEach((event) => {
      window.removeEventListener(event, this.resetTimeout);
    });
  }
}
