/**
 * OmniLease API Middleware
 * Standardized logging and error handling for the Express server.
 */

const logger = (req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
        const duration = Date.now() - start;
        console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} ${res.statusCode} - ${duration}ms`);
    });
    next();
};

const errorHandler = (err, req, res, next) => {
    console.error(`[ERROR] ${err.stack}`);
    
    const statusCode = err.statusCode || 500;
    const message = err.message || 'Internal Server Error';
    
    res.status(statusCode).json({
        success: false,
        error: message,
        timestamp: new Date().toISOString()
    });
};

const validateQuoteParams = (req, res, next) => {
    const { collection, tokenId, duration } = req.query;
    if (!collection || !tokenId || !duration) {
        return res.status(400).json({
            success: false,
            error: 'Missing required parameters: collection, tokenId, duration'
        });
    }
    next();
};

module.exports = {
    logger,
    errorHandler,
    validateQuoteParams
};