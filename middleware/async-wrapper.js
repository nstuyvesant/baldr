// Middleware enabling async functions to use Express default error-handling
module.exports = fn => async(req, res, next) => {
  try {
    await fn(req, res, next);
  } catch(err) {
    return next(err);
  }
};
