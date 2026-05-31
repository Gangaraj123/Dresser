# Backend Refactoring & Cleanup Guide

> **Purpose:** Feed this entire document to an AI assistant along with your codebase. It will serve as the ruleset and instructions for a full backend refactor — structure, logging, error handling, validation, and production readiness.

---

## How to Use This Guide

**Do NOT try to refactor everything in one prompt.** Follow this phased approach:

| Phase | Focus | Prompt Prefix |
|-------|-------|---------------|
| 1 | Project structure & layering | *"Using the guide, refactor the project structure..."* |
| 2 | Structured logging | *"Using the guide, add structured logging..."* |
| 3 | Centralized error handling | *"Using the guide, implement centralized error handling..."* |
| 4 | Input validation | *"Using the guide, add input validation..."* |
| 5 | Health checks & response format | *"Using the guide, add health checks and standardize responses..."* |
| 6 | Security & middleware hardening | *"Using the guide, harden middleware and security..."* |
| 7 | Final review | *"Using the guide, do a final staff-engineer review..."* |

After each phase, test your app before moving to the next.

---

## Phase 1: Project Structure & Layering

### Target Directory Layout

```
/src
  /config            → App config, env vars, constants
    index.js         → Central config object (reads from process.env)

  /routes            → Route definitions ONLY (no logic)
    userRoutes.js
    orderRoutes.js

  /controllers       → Thin request/response handlers
    userController.js
    orderController.js

  /services          → ALL business logic lives here
    userService.js
    orderService.js

  /repositories      → Database queries ONLY (no business logic)
    userRepository.js
    orderRepository.js

  /middlewares        → Reusable middleware
    requestLogger.js
    authenticate.js
    validate.js
    rateLimiter.js
    errorHandler.js

  /utils              → Pure helper functions
    responseFormatter.js
    idGenerator.js

  /errors             → Custom error classes
    AppError.js
    NotFoundError.js
    ValidationError.js

  /validators         → Request schema definitions
    userSchemas.js
    orderSchemas.js

  /health             → Health check logic
    healthController.js

  app.js              → Express app setup (middleware, routes)
  server.js           → Server start (listen, graceful shutdown)
  logger.js           → Logger configuration (single source of truth)
```

### Rules for the AI

```
STRICT RULES — PROJECT STRUCTURE:

1. Controllers are THIN.
   - Controllers ONLY extract data from req, call a service, and send the response.
   - No database calls. No business logic. No data transformation.
   - Max ~15 lines per controller method.

2. Services contain ALL business logic.
   - Services call repositories for data access.
   - Services call other services if needed.
   - Services NEVER import req or res — they receive plain data and return plain data.

3. Repositories are the ONLY layer that touches the database.
   - One repository per data model/table.
   - Returns plain objects, not ORM-specific instances (when possible).

4. Routes only define HTTP method + path + controller method + middleware chain.
   - No inline logic in route files.

5. No circular dependencies between layers.
   - Flow: Route → Controller → Service → Repository
   - Never: Repository → Service or Controller → Route

6. Config lives in /config/index.js.
   - Every env var is read ONCE in config.
   - The rest of the app imports from config, never from process.env directly.
   - Provide sensible defaults for development.
```

### Example: Correct Controller

```javascript
// controllers/userController.js
const userService = require('../services/userService');
const { formatSuccess } = require('../utils/responseFormatter');

const getUser = async (req, res, next) => {
  try {
    const user = await userService.getUserById(req.params.id);
    res.json(formatSuccess(user, req.requestId));
  } catch (err) {
    next(err); // Let the centralized error handler deal with it
  }
};

module.exports = { getUser };
```

### Example: Correct Service

```javascript
// services/userService.js
const userRepository = require('../repositories/userRepository');
const { NotFoundError } = require('../errors/NotFoundError');

const getUserById = async (id) => {
  const user = await userRepository.findById(id);
  if (!user) throw new NotFoundError(`User not found: ${id}`);
  return user;
};

module.exports = { getUserById };
```

---

## Phase 2: Structured Logging

### Goal

Replace every `console.log` with structured, JSON-formatted logs that are ready for any log management tool (ELK, Datadog, Grafana Loki, CloudWatch, etc.) later.

### Logger Setup (Development-First)

```javascript
// logger.js — SINGLE SOURCE OF TRUTH for logging
const pino = require('pino');
const config = require('./config');

const logger = pino({
  level: config.logLevel || 'info',

  // Pretty print for development, raw JSON for production
  transport: config.nodeEnv === 'development'
    ? { target: 'pino-pretty', options: { colorize: true, translateTime: 'SYS:yyyy-mm-dd HH:MM:ss', ignore: 'pid,hostname' } }
    : undefined,

  // Base fields attached to EVERY log line
  base: {
    service: config.serviceName || 'my-api',
    env: config.nodeEnv,
  },

  // Customize serializers to avoid logging sensitive data
  serializers: {
    req: (req) => ({
      method: req.method,
      url: req.url,
      requestId: req.requestId,
    }),
    res: (res) => ({
      statusCode: res.statusCode,
    }),
    err: pino.stdSerializers.err,
  },
});

module.exports = logger;
```

**Dependencies:**
```bash
npm install pino pino-pretty
```

### What Must Be Logged

Every log line MUST include these fields at minimum:

| Field | Source | Why |
|-------|--------|-----|
| `requestId` | Generated per request (UUID) | Trace a single request across all logs |
| `timestamp` | Auto by Pino | Chronological ordering |
| `level` | info / warn / error / debug | Filtering |
| `message` | Descriptive string | Human readability |

Additional fields to include when available:

| Field | When |
|-------|------|
| `userId` | After authentication |
| `method` + `url` | On every request |
| `statusCode` | On response |
| `latencyMs` | On response |
| `error.message` + `error.stack` | On errors |
| `externalService` + `externalLatencyMs` | On external API calls |

### Request ID Middleware

```javascript
// middlewares/requestId.js
const { randomUUID } = require('crypto');

const attachRequestId = (req, res, next) => {
  // Accept incoming request ID from headers (for distributed tracing) or generate one
  req.requestId = req.headers['x-request-id'] || randomUUID();
  res.setHeader('x-request-id', req.requestId);
  next();
};

module.exports = attachRequestId;
```

### Request Logging Middleware

```javascript
// middlewares/requestLogger.js
const logger = require('../logger');

const requestLogger = (req, res, next) => {
  const start = Date.now();

  // Log request start
  req.log = logger.child({ requestId: req.requestId });
  req.log.info({ method: req.method, url: req.originalUrl }, 'Request started');

  // Log response end
  res.on('finish', () => {
    const latencyMs = Date.now() - start;
    const logData = {
      method: req.method,
      url: req.originalUrl,
      statusCode: res.statusCode,
      latencyMs,
    };

    if (res.statusCode >= 500) {
      req.log.error(logData, 'Request failed');
    } else if (res.statusCode >= 400) {
      req.log.warn(logData, 'Request client error');
    } else {
      req.log.info(logData, 'Request completed');
    }
  });

  next();
};

module.exports = requestLogger;
```

### Rules for the AI

```
STRICT RULES — LOGGING:

1. Delete EVERY console.log, console.error, console.warn, console.info.
   Replace with the appropriate logger method: logger.debug, logger.info, logger.warn, logger.error.

2. NEVER log sensitive data:
   - No passwords, tokens, API keys, credit card numbers
   - No full request bodies (log only schema-safe summaries if needed)
   - Sanitize user emails in debug logs

3. Use child loggers in services:
   const log = logger.child({ module: 'userService', requestId });
   This keeps context without passing the whole req object.

4. Log external calls:
   Before and after every external HTTP call, database query, or cache operation,
   log the target, operation, and latency.

5. Error logs MUST include:
   - error.message
   - error.stack
   - requestId
   - The operation that failed

6. Log levels:
   - debug: Detailed internal state (only in development)
   - info: Normal operations (request start/end, business events)
   - warn: Recoverable issues (missing optional field, retry, deprecation)
   - error: Failures (unhandled errors, external service failures, DB errors)

7. The logger is configured ONCE in logger.js. No other file creates its own logger.
```

### Development vs. Production

```
Development (NODE_ENV=development):
  - pino-pretty enabled → human-readable colored output in terminal
  - Log level: debug
  - Example output:
    [2026-04-03 10:00:00] INFO (my-api): Request started
      requestId: "abc-123"
      method: "GET"
      url: "/api/users/42"

Production (NODE_ENV=production):
  - Raw JSON output → pipe to any log collector
  - Log level: info (no debug noise)
  - Example output:
    {"level":30,"time":1711958400000,"service":"my-api","requestId":"abc-123","method":"GET","url":"/api/users/42","msg":"Request started"}
```

### Preparing for Log Management Tools Later

Your structured JSON logs are already compatible with:

| Tool | Integration |
|------|-------------|
| **ELK Stack** | Pipe stdout → Filebeat → Elasticsearch |
| **Datadog** | Pipe stdout → Datadog Agent (auto-parses JSON) |
| **Grafana Loki** | Pipe stdout → Promtail → Loki |
| **AWS CloudWatch** | Container stdout auto-captured |
| **Google Cloud Logging** | Container stdout auto-captured |

No code changes needed later — just configure the log collector to read stdout/stderr.

---

## Phase 3: Centralized Error Handling

### Custom Error Classes

```javascript
// errors/AppError.js
class AppError extends Error {
  constructor(message, statusCode = 500, errorCode = 'INTERNAL_ERROR') {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.isOperational = true; // Distinguish from programmer errors
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
```

```javascript
// errors/NotFoundError.js
const AppError = require('./AppError');

class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404, 'NOT_FOUND');
  }
}

module.exports = NotFoundError;
```

```javascript
// errors/ValidationError.js
const AppError = require('./AppError');

class ValidationError extends AppError {
  constructor(details) {
    super('Validation failed', 400, 'VALIDATION_ERROR');
    this.details = details; // Array of field-level errors
  }
}

module.exports = ValidationError;
```

Create similar classes for: `UnauthorizedError (401)`, `ForbiddenError (403)`, `ConflictError (409)`, `RateLimitError (429)`.

### Global Error Handler Middleware

```javascript
// middlewares/errorHandler.js
const logger = require('../logger');
const { formatError } = require('../utils/responseFormatter');

const errorHandler = (err, req, res, _next) => {
  // Default to 500 if no status code set
  const statusCode = err.statusCode || 500;
  const requestId = req.requestId || 'unknown';

  // Log the error
  if (statusCode >= 500) {
    // Server errors: log full stack
    (req.log || logger).error({
      err,
      requestId,
      method: req.method,
      url: req.originalUrl,
    }, `Unhandled error: ${err.message}`);
  } else {
    // Client errors: log warning (no stack needed)
    (req.log || logger).warn({
      errorCode: err.errorCode,
      message: err.message,
      requestId,
    }, `Client error: ${err.message}`);
  }

  // Send response — NEVER expose stack traces to the client
  res.status(statusCode).json(formatError({
    message: statusCode >= 500 ? 'Internal server error' : err.message,
    errorCode: err.errorCode || 'INTERNAL_ERROR',
    details: err.details || null,
    requestId,
  }));
};

module.exports = errorHandler;
```

### Rules for the AI

```
STRICT RULES — ERROR HANDLING:

1. REMOVE scattered try/catch blocks from controllers.
   Controllers should either:
   a) Use a single try/catch that calls next(err), OR
   b) Use an asyncHandler wrapper that auto-catches:

   const asyncHandler = (fn) => (req, res, next) =>
     Promise.resolve(fn(req, res, next)).catch(next);

   // Usage in routes:
   router.get('/users/:id', asyncHandler(userController.getUser));

2. Services throw custom errors — they NEVER send HTTP responses.
   throw new NotFoundError('User');    // NOT res.status(404)...
   throw new ValidationError([...]);   // NOT res.status(400)...

3. The global errorHandler middleware is registered LAST in app.js:
   app.use(errorHandler);  // Must be after all routes

4. NEVER expose error.stack or internal details in API responses.
   In production, 500 errors return only: "Internal server error"

5. Handle unhandled rejections and uncaught exceptions at the process level:
   process.on('unhandledRejection', (reason) => { logger.fatal(reason); process.exit(1); });
   process.on('uncaughtException', (err) => { logger.fatal(err); process.exit(1); });
   Place these in server.js, NOT inside app.js.

6. All errors that reach the error handler MUST be logged with requestId.
```

---

## Phase 4: Input Validation

### Schema Definitions with Zod

```javascript
// validators/userSchemas.js
const { z } = require('zod');

const createUserSchema = z.object({
  body: z.object({
    name: z.string().min(1, 'Name is required').max(100),
    email: z.string().email('Invalid email format'),
    age: z.number().int().min(13).max(120).optional(),
    role: z.enum(['user', 'admin']).default('user'),
  }),
});

const getUserSchema = z.object({
  params: z.object({
    id: z.string().uuid('Invalid user ID format'),
  }),
});

const listUsersSchema = z.object({
  query: z.object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    search: z.string().max(200).optional(),
  }),
});

module.exports = { createUserSchema, getUserSchema, listUsersSchema };
```

### Validation Middleware

```javascript
// middlewares/validate.js
const { ValidationError } = require('../errors/ValidationError');

const validate = (schema) => (req, _res, next) => {
  const result = schema.safeParse({
    body: req.body,
    params: req.params,
    query: req.query,
  });

  if (!result.success) {
    const details = result.error.issues.map((issue) => ({
      field: issue.path.join('.'),
      message: issue.message,
    }));
    return next(new ValidationError(details));
  }

  // Replace req data with parsed (coerced + defaulted) values
  req.body = result.data.body ?? req.body;
  req.params = result.data.params ?? req.params;
  req.query = result.data.query ?? req.query;

  next();
};

module.exports = validate;
```

### Usage in Routes

```javascript
// routes/userRoutes.js
const router = require('express').Router();
const userController = require('../controllers/userController');
const validate = require('../middlewares/validate');
const { createUserSchema, getUserSchema, listUsersSchema } = require('../validators/userSchemas');
const asyncHandler = require('../utils/asyncHandler');

router.get('/', validate(listUsersSchema), asyncHandler(userController.listUsers));
router.get('/:id', validate(getUserSchema), asyncHandler(userController.getUser));
router.post('/', validate(createUserSchema), asyncHandler(userController.createUser));

module.exports = router;
```

### Rules for the AI

```
STRICT RULES — VALIDATION:

1. EVERY route MUST have a validation schema.
   No exceptions. Even if a route takes no params, validate that body is empty.

2. Validate ALL input sources: body, params, query, headers (where relevant).

3. Use coercion for query params (they arrive as strings).

4. Schemas are defined in /validators/, NOT inline in routes or controllers.

5. The validate middleware handles error formatting —
   controllers should NEVER manually check req.body fields.

6. Strip unknown fields by default (z.object().strict() or z.object().strip()).
```

---

## Phase 5: Health Checks & Standard Response Format

### Health Endpoints

```javascript
// health/healthController.js
const logger = require('../logger');

// Basic health — for load balancers and uptime monitors
const basicHealth = (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
};

// Deep health — checks all dependencies
const deepHealth = async (req, res) => {
  const checks = {};

  // Database check
  try {
    const start = Date.now();
    await db.raw('SELECT 1'); // Replace with your DB client
    checks.database = { status: 'ok', latencyMs: Date.now() - start };
  } catch (err) {
    checks.database = { status: 'error', message: err.message };
  }

  // Redis check (if applicable)
  try {
    const start = Date.now();
    await redis.ping(); // Replace with your Redis client
    checks.redis = { status: 'ok', latencyMs: Date.now() - start };
  } catch (err) {
    checks.redis = { status: 'error', message: err.message };
  }

  const allHealthy = Object.values(checks).every((c) => c.status === 'ok');

  res.status(allHealthy ? 200 : 503).json({
    status: allHealthy ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks,
  });
};

module.exports = { basicHealth, deepHealth };
```

### Standard Response Format

```javascript
// utils/responseFormatter.js

const formatSuccess = (data, requestId, meta = null) => ({
  success: true,
  data,
  error: null,
  requestId,
  ...(meta && { meta }), // Pagination, counts, etc.
});

const formatError = ({ message, errorCode, details, requestId }) => ({
  success: false,
  data: null,
  error: {
    message,
    code: errorCode,
    ...(details && { details }),
  },
  requestId,
});

module.exports = { formatSuccess, formatError };
```

### Example Responses

```json
// Success
{
  "success": true,
  "data": { "id": "abc-123", "name": "Jane Doe" },
  "error": null,
  "requestId": "req-550e8400"
}

// Success with pagination
{
  "success": true,
  "data": [{ "id": "1" }, { "id": "2" }],
  "error": null,
  "requestId": "req-550e8400",
  "meta": { "page": 1, "limit": 20, "total": 57 }
}

// Client Error
{
  "success": false,
  "data": null,
  "error": {
    "message": "Validation failed",
    "code": "VALIDATION_ERROR",
    "details": [
      { "field": "body.email", "message": "Invalid email format" }
    ]
  },
  "requestId": "req-550e8400"
}

// Server Error (production — no internal details)
{
  "success": false,
  "data": null,
  "error": {
    "message": "Internal server error",
    "code": "INTERNAL_ERROR"
  },
  "requestId": "req-550e8400"
}
```

### Rules for the AI

```
STRICT RULES — RESPONSES:

1. EVERY endpoint uses formatSuccess or formatError. No raw res.json({ ... }).

2. Pagination responses include a meta object with page, limit, total.

3. Health endpoints are NOT behind authentication.
   /health — public, lightweight, no DB calls.
   /health/deep — optionally behind internal auth, checks dependencies.

4. NEVER return raw database errors or stack traces in any response.
```

---

## Phase 6: Security & Middleware Hardening

### App Setup (app.js)

```javascript
// app.js — Middleware order matters!
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');

const attachRequestId = require('./middlewares/requestId');
const requestLogger = require('./middlewares/requestLogger');
const rateLimiter = require('./middlewares/rateLimiter');
const errorHandler = require('./middlewares/errorHandler');
const { basicHealth, deepHealth } = require('./health/healthController');
const config = require('./config');

const app = express();

// 1. Security headers
app.use(helmet());

// 2. CORS
app.use(cors({ origin: config.allowedOrigins }));

// 3. Body parsing with size limits
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// 4. Request ID (before logging)
app.use(attachRequestId);

// 5. Request logging
app.use(requestLogger);

// 6. Rate limiting
app.use('/api/', rateLimiter);

// 7. Health checks (before auth, always accessible)
app.get('/health', basicHealth);
app.get('/health/deep', deepHealth);

// 8. API routes
app.use('/api/users', require('./routes/userRoutes'));
app.use('/api/orders', require('./routes/orderRoutes'));

// 9. 404 handler
app.use((_req, _res, next) => {
  const err = new Error('Route not found');
  err.statusCode = 404;
  err.errorCode = 'ROUTE_NOT_FOUND';
  next(err);
});

// 10. Global error handler — MUST BE LAST
app.use(errorHandler);

module.exports = app;
```

### Graceful Shutdown (server.js)

```javascript
// server.js
const app = require('./app');
const config = require('./config');
const logger = require('./logger');

const server = app.listen(config.port, () => {
  logger.info({ port: config.port, env: config.nodeEnv }, 'Server started');
});

// Graceful shutdown
const shutdown = (signal) => {
  logger.info({ signal }, 'Shutdown signal received');
  server.close(() => {
    logger.info('HTTP server closed');
    // Close DB connections, Redis, etc. here
    process.exit(0);
  });

  // Force exit after timeout
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
  logger.fatal({ err: reason }, 'Unhandled rejection');
  process.exit(1);
});
process.on('uncaughtException', (err) => {
  logger.fatal({ err }, 'Uncaught exception');
  process.exit(1);
});
```

### Config (config/index.js)

```javascript
// config/index.js — Every env var is read HERE and nowhere else
require('dotenv').config();

module.exports = {
  port: parseInt(process.env.PORT, 10) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  logLevel: process.env.LOG_LEVEL || 'debug',
  serviceName: process.env.SERVICE_NAME || 'my-api',
  allowedOrigins: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    name: process.env.DB_NAME || 'myapp_dev',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '',
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret-change-me',
    expiresIn: process.env.JWT_EXPIRES_IN || '24h',
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 15 * 60 * 1000,
    max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 100,
  },
};
```

### Rules for the AI

```
STRICT RULES — SECURITY & PRODUCTION READINESS:

1. ZERO console.log statements. Delete all of them. Use logger.

2. ZERO hardcoded secrets, ports, URLs, or credentials.
   Everything goes through config/index.js → process.env.

3. Helmet is ALWAYS used.

4. Body size limits are ALWAYS set.

5. Rate limiting is ALWAYS applied to API routes.

6. Graceful shutdown handles SIGTERM and SIGINT.

7. Unhandled rejections and uncaught exceptions log and exit.

8. Never commit .env files. Provide a .env.example instead.
```

---

## Phase 7: Final Review Prompt

After all phases are complete, use this prompt for a final audit:

```
You are a staff backend engineer performing a production readiness review.

Review this codebase against EVERY rule below. For each violation, give the
exact file, line, and a concrete fix.

CHECKLIST:

Architecture:
  [ ] Controllers are thin (no business logic, no DB calls)
  [ ] Services contain all business logic
  [ ] Repositories are the only DB-touching layer
  [ ] No circular dependencies
  [ ] Config reads env vars in one place

Logging:
  [ ] Zero console.log / console.error / console.warn
  [ ] Every log line includes requestId
  [ ] Structured JSON format (Pino or Winston)
  [ ] No sensitive data in logs (passwords, tokens, keys)
  [ ] External calls are logged with latency
  [ ] Error logs include stack traces

Error Handling:
  [ ] Single global error handler middleware
  [ ] Custom error classes extend AppError
  [ ] Services throw errors, never send responses
  [ ] No raw try/catch in controllers (use asyncHandler)
  [ ] 500 errors never expose internals to clients
  [ ] Unhandled rejections and uncaught exceptions are caught at process level

Validation:
  [ ] Every route has an input validation schema
  [ ] Body, params, and query are all validated
  [ ] Unknown fields are stripped or rejected
  [ ] Validation errors return structured details

Responses:
  [ ] All responses use formatSuccess / formatError
  [ ] Consistent shape: { success, data, error, requestId }
  [ ] Pagination includes meta object

Health:
  [ ] /health exists and is lightweight
  [ ] /health/deep checks DB and dependencies
  [ ] Health endpoints are not behind auth

Security:
  [ ] Helmet enabled
  [ ] CORS configured
  [ ] Rate limiting on API routes
  [ ] Body size limits set
  [ ] No hardcoded secrets or credentials
  [ ] .env.example provided, .env gitignored

Production:
  [ ] Graceful shutdown on SIGTERM/SIGINT
  [ ] Process-level error handlers
  [ ] Separate app.js and server.js
  [ ] Environment-aware logger (pretty dev, JSON prod)

For each violation found, output:
  FILE: <path>
  ISSUE: <description>
  FIX: <exact code change>
```

---

## Appendix A: Async Handler Utility

```javascript
// utils/asyncHandler.js
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

module.exports = asyncHandler;
```

## Appendix B: Rate Limiter

```javascript
// middlewares/rateLimiter.js
const rateLimit = require('express-rate-limit');
const config = require('../config');

module.exports = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    data: null,
    error: {
      message: 'Too many requests, please try again later',
      code: 'RATE_LIMIT_EXCEEDED',
    },
  },
});
```

## Appendix C: Full Dependency List

```bash
# Core
npm install express dotenv

# Logging
npm install pino pino-pretty

# Security
npm install helmet cors express-rate-limit

# Validation
npm install zod

# Dev
npm install --save-dev nodemon
```

## Appendix D: .env.example

```env
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug
SERVICE_NAME=my-api

DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp_dev
DB_USER=postgres
DB_PASSWORD=

JWT_SECRET=change-me-in-production
JWT_EXPIRES_IN=24h

ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173

RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=100
```
