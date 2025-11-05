#!/bin/bash
# Export all PromEx dashboards for all services

cd "$(dirname "$0")/.."

echo "Exporting PromEx dashboards..."

# Job Service
echo "  ↳ JobSvc dashboards..."
cd apps/job_svc
mix prom_ex.dashboard.export --dashboard application.json --module JobSvc.PromEx --stdout > ../../grafana/dashboards/job_svc_application.json 2>/dev/null
mix prom_ex.dashboard.export --dashboard beam.json --module JobSvc.PromEx --stdout > ../../grafana/dashboards/job_svc_beam.json 2>/dev/null
cd ../..

# Image Service
echo "  ↳ ImageSvc dashboards..."
cd apps/image_svc
mix prom_ex.dashboard.export --dashboard application.json --module ImageSvc.PromEx --stdout > ../../grafana/dashboards/image_svc_application.json 2>/dev/null
mix prom_ex.dashboard.export --dashboard beam.json --module ImageSvc.PromEx --stdout > ../../grafana/dashboards/image_svc_beam.json 2>/dev/null
cd ../..

# Email Service
echo "  ↳ EmailSvc dashboards..."
cd apps/email_svc
mix prom_ex.dashboard.export --dashboard application.json --module EmailSvc.PromEx --stdout > ../../grafana/dashboards/email_svc_application.json 2>/dev/null
mix prom_ex.dashboard.export --dashboard beam.json --module EmailSvc.PromEx --stdout > ../../grafana/dashboards/email_svc_beam.json 2>/dev/null
cd ../..

# Client Service
echo "  ↳ ClientSvc dashboards..."
cd apps/client_svc
mix prom_ex.dashboard.export --dashboard application.json --module ClientSvc.PromEx --stdout > ../../grafana/dashboards/client_svc_application.json 2>/dev/null
mix prom_ex.dashboard.export --dashboard beam.json --module ClientSvc.PromEx --stdout > ../../grafana/dashboards/client_svc_beam.json 2>/dev/null
cd ../..

echo "✓ All dashboards exported to grafana/dashboards/"
echo ""
echo "Import them in Grafana:"
echo "  1. Open http://localhost:3000"
echo "  2. Click + → Import dashboard → Upload JSON file"
echo "  3. Select a dashboard file from grafana/dashboards/"
