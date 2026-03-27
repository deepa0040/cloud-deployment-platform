#!/bin/bash
# Validate that the service is running
curl -f http://localhost:3000/health || exit 1