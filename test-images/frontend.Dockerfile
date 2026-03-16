# @req SCI-ANS-001
# Minimal dummy frontend image for E2E infrastructure testing
FROM nginx:1.25-alpine

# Create simple HTML page
RUN echo '<!DOCTYPE html><html><head><title>SDD Navigator</title></head><body><h1>SDD Navigator Test</h1></body></html>' > /usr/share/nginx/html/index.html

EXPOSE 80