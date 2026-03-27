# Application Code Documentation

## Overview

This is a simple Express.js web server that runs on Node.js. The application listens on port 3000 and provides two HTTP endpoints:

1. **Root endpoint** (`/`) - Returns a welcome message
2. **Health endpoint** (`/health`) - Returns an OK status for health checks

## Application Code

### [server.js](sample-app/server.js)

```javascript
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Root endpoint - welcome message
app.get('/', (req, res) => {
  res.send('Hello World from CodeDeploy V2!');
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Start the server
app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
```

#### Code Breakdown

**1. Import Express**
```javascript
const express = require('express');
```
- Imports Express.js framework for building HTTP servers

**2. Create Express Application**
```javascript
const app = express();
```
- Creates an Express application instance

**3. Define Port**
```javascript
const port = process.env.PORT || 3000;
```
- Uses environment variable `PORT` if set, otherwise defaults to port 3000
- Allows flexible port configuration without code changes

**4. Root Route Handler**
```javascript
app.get('/', (req, res) => {
  res.send('Hello World from CodeDeploy V2!');
});
```
- Handles HTTP GET requests to `/`
- Returns a simple text response
- `V2` indicates the updated version after deployment

**5. Health Check Endpoint**
```javascript
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});
```
- Provides a health check endpoint for load balancers and monitoring
- Returns HTTP 200 with status "OK"
- Used by CodeDeploy's `ValidateService` hook to verify deployment success

**6. Start Server**
```javascript
app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
```
- Starts the Express server listening on the specified port
- Logs confirmation message with the listening address

## Dependencies

### [package.json](sample-app/package.json)

```json
{
  "name": "sample-node-app",
  "version": "1.0.0",
  "description": "A simple Node.js web application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

#### Explanation

- **name**: Package identifier for npm
- **version**: Current application version (1.0.0)
- **description**: Brief description of the application
- **main**: Entry point file (server.js)
- **scripts.start**: Command to start the app (`npm start`)
- **dependencies.express**: Express.js framework v4.18.2

## Usage

### Local Development

```bash
# Install dependencies
npm install

# Start the server
npm start
```

Server will output:
```
App listening at http://localhost:3000
```

### Test Endpoints

**Root endpoint:**
```bash
curl http://localhost:3000/
# Output: Hello World from CodeDeploy V2!
```

**Health endpoint:**
```bash
curl http://localhost:3000/health
# Output: OK
```

### Using a Different Port

```bash
PORT=8080 npm start
# Server listens on port 8080
```

## Deployment Context

### How CodeDeploy Uses This Code

1. **BeforeInstall** → `npm install` installs Express and dependencies
2. **ApplicationStart** → `npm start` launches `node server.js`
3. **ValidateService** → `curl http://localhost:3000/health` verifies deployment

### File Structure During Deployment

After deployment, files are located at:
```
/var/www/sample-app/
├── package.json
├── server.js
├── appspec.yml
└── scripts/
    ├── install_dependencies.sh
    ├── start_server.sh
    ├── stop_server.sh
    └── validate_service.sh
```

## Extending the Application

### Add a New Route
```javascript
app.get('/status', (req, res) => {
  res.json({ 
    status: 'running', 
    version: '2.0.0',
    uptime: process.uptime()
  });
});
```

### Add Middleware (Logger)
```javascript
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});
```

### Add Error Handling
```javascript
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal Server Error' });
});
```

### Add JSON Response
```javascript
app.get('/api/info', (req, res) => {
  res.json({
    name: 'sample-node-app',
    version: '2.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});
```

## Environment Variables

The application supports:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server listening port | 3000 |
| `NODE_ENV` | Environment (dev/prod) | (not set) |

### Example Production Setup

```bash
export NODE_ENV=production
export PORT=3000
npm start
```

## Performance Considerations

**Current Setup:**
- Single-threaded Node.js process
- Suitable for low-to-medium traffic
- No clustering or load balancing

**For Production:**
- Use PM2 or similar for process management
- Deploy multiple instances with load balancer
- Add caching (Redis)
- Implement rate limiting
- Add request/query timeouts

## Logging

The application logs to:
- **Console**: Visible during `npm start`
- **File (CodeDeploy)**: `/tmp/sample-app.log` (set by start_server.sh)

To view logs:
```bash
sudo tail -f /tmp/sample-app.log
```

## Next Steps

1. **Add database connectivity** (PostgreSQL, MongoDB)
2. **Implement authentication** (JWT, OAuth)
3. **Add environment-specific configs** (.env files)
4. **Set up proper error handling** and logging
5. **Add unit and integration tests**
6. **Implement request validation** and sanitization
7. **Add API documentation** (Swagger/OpenAPI)
8. **Set up monitoring and alerting**
