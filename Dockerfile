# PRSMTECH CRM - Railway Deployment
# Based on Frappe CRM with custom enterprise features

FROM frappe/bench:v5.22.0

# Set environment variables
ENV SHELL=/bin/bash
ENV FRAPPE_USER=frappe
ENV BENCH_PATH=/home/frappe/frappe-bench

# Switch to frappe user
USER frappe
WORKDIR /home/frappe

# Initialize bench if not exists
RUN bench init --skip-redis-config-generation frappe-bench --version version-15

WORKDIR ${BENCH_PATH}

# Get CRM app
RUN bench get-app crm --branch main

# Expose ports
EXPOSE 8000 9000

# Copy custom startup script
COPY --chown=frappe:frappe docker/railway-init.sh /home/frappe/railway-init.sh
RUN chmod +x /home/frappe/railway-init.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/api/method/frappe.ping || exit 1

# Start command
CMD ["/home/frappe/railway-init.sh"]
